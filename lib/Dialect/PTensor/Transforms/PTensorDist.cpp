//===- PTensorDist.cpp - PTensorToDist Transform  ---------------*- C++ -*-===//
//
// Copyright 2022 Intel Corporation
// Part of the IMEX Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// This file implements transform of the PTensor dialect to a combination of
/// PTensor and Dist dialects.
///
/// PTensor operations will stay untouched unless operands are distributed
/// PTensors. PTensors are converted do DistTensorTypes by creation functions,
/// for example by reacting on an input argument 'team'. When creating a
/// DistTensor a DistInfo ist attached which provides information to preform
/// distributed operations, such as shape and offsets of the local partition.
/// If operations work on distributed tensors necessary communication with the
/// runtime is performed to identify the local partition.
/// The local tensor is extracted/created and the operation is
/// re-issued for the local part. No deep recursion happens because the operands
/// for the newly created ptensor operations are not distributed. Finally
/// additional ops are added of more communication with the runtime is needed,
/// for example to perform a final global reduction.
///
/// Note: distributed tensors cannot cross function boundaries (as of yet).
///
//===----------------------------------------------------------------------===//

#include <imex/Dialect/Dist/IR/DistOps.h>
#include <imex/Dialect/PTensor/IR/PTensorOps.h>
#include <imex/Dialect/PTensor/Transforms/Utils.h>
#include <imex/internal/PassWrapper.h>

#include <mlir/Conversion/LLVMCommon/TypeConverter.h>
#include <mlir/Dialect/Arith/IR/Arith.h>
#include <mlir/Dialect/Func/IR/FuncOps.h>
#include <mlir/Dialect/LLVMIR/LLVMDialect.h>
#include <mlir/Dialect/Linalg/IR/Linalg.h>
#include <mlir/Dialect/Shape/IR/Shape.h>
#include <mlir/Dialect/Tensor/IR/Tensor.h>
#include <mlir/IR/BuiltinOps.h>
#include <mlir/IR/PatternMatch.h>
#include <mlir/Rewrite/FrozenRewritePatternSet.h>

#include "PassDetail.h"

namespace imex {

namespace {

// *******************************
// ***** Some helper functions ***
// *******************************

// create ::imex::dist::DistInfoOp
inline ::mlir::Value createDistInfo(::mlir::Location &loc,
                                    ::mlir::OpBuilder &builder, uint64_t rank,
                                    ::mlir::Value gshape, ::mlir::Value team) {
  return builder.create<::imex::dist::DistInfoOp>(
      loc, ::imex::dist::DistInfoType::get(builder.getContext(), rank),
      getIntAttr<64>(builder, rank), gshape, team);
}

// create ::imex::dist::LocalShapeOp
inline ::mlir::Value createGetLocalShape(::mlir::Location &loc,
                                         ::mlir::OpBuilder &builder,
                                         ::mlir::Value info) {
  return builder.create<::imex::dist::ExtractFromInfoOp>(
      loc, ::imex::dist::LSHAPE, info);
}

// create ::imex::dist::LocalOffsetsOp
inline ::mlir::Value createGetLocalOffsets(::mlir::Location &loc,
                                           ::mlir::OpBuilder &builder,
                                           ::mlir::Value info) {
  return builder.create<::imex::dist::ExtractFromInfoOp>(
      loc, ::imex::dist::LOFFSETS, info);
}

// extract RankedTensor and create ::imex::dist::AllReduceOp
inline ::mlir::Value createAllReduce(::mlir::Location &loc,
                                     ::mlir::OpBuilder &builder,
                                     ::mlir::Attribute op,
                                     ::mlir::Value pTnsr) {
  auto pTnsrTyp = pTnsr.getType().dyn_cast<::imex::ptensor::PTensorType>();
  assert(pTnsrTyp);
  auto rTnsr = builder.create<::imex::ptensor::ExtractRTensorOp>(
      loc, pTnsrTyp.getRtensor(), pTnsr);
  return builder.create<::imex::dist::AllReduceOp>(loc, rTnsr.getType(), op,
                                                   rTnsr);
}

// create ops to extract the local RankedTensor from DistTensor
inline ::mlir::Value createGetLocal(::mlir::Location &loc,
                                    ::mlir::OpBuilder &builder,
                                    ::mlir::Value pt) {
  auto dtTyp = pt.getType().dyn_cast<::imex::dist::DistTensorType>();
  assert(dtTyp);
  auto dTnsr = builder.create<::imex::dist::GetPTensorOp>(loc, pt);
  auto ptTyp = dTnsr.getType().dyn_cast<::imex::ptensor::PTensorType>();
  assert(ptTyp);
  auto rtnsr = builder.create<::imex::ptensor::ExtractRTensorOp>(
      loc, ptTyp.getRtensor(), dTnsr);
  // FIXME: device
  return builder.create<::imex::ptensor::MkPTensorOp>(loc, rtnsr);
}

// Create a DistTensor from a PTensor and DistInfo
inline ::mlir::Value createMkTnsr(::mlir::Location &loc,
                                  ::mlir::OpBuilder &builder, ::mlir::Value pt,
                                  ::mlir::Value info) {
  return builder.create<::imex::dist::InitDistTensorOp>(loc, pt, info);
}

// extract team component from given DistTensor
inline ::mlir::Value createTeamOf(::mlir::Location &loc,
                                  ::mlir::OpBuilder &builder,
                                  ::mlir::Value pt) {
  auto ptTyp = pt.getType().dyn_cast<::imex::dist::DistTensorType>();
  assert(ptTyp);
  auto rank = ptTyp.getPTensorType().getRtensor().getRank();
  auto info = builder.create<::imex::dist::GetInfoOp>(
      loc, ::imex::dist::DistInfoType::get(builder.getContext(), rank), pt);
  return builder.create<::imex::dist::ExtractFromInfoOp>(
      loc, ::imex::dist::TEAM, info);
}

// *******************************
// ***** Individual patterns *****
// *******************************

// Base-class for RewriterPatterns which handle recursion
// All our rewriters replace ops with series of ops including the
// op-type which gets rewritten. Rewriters will not rewrite (stop recursion)
// if input PTensor operands are not distributed.
template <typename T>
struct RecOpRewritePattern : public ::mlir::OpRewritePattern<T> {
  using ::mlir::OpRewritePattern<T>::OpRewritePattern;
  /// Initialize the pattern.
  void initialize() {
    /// Signal that this pattern safely handles recursive application.
    RecOpRewritePattern<T>::setHasBoundedRewriteRecursion();
  }
};

/// Rewriting ::imex::ptensor::ExtractRTensorOp
/// Get PTensor from DistTensor and apply to ExtractTensorOp.
struct DistExtractRTensorOpRWP
    : public RecOpRewritePattern<::imex::ptensor::ExtractRTensorOp> {
  using RecOpRewritePattern::RecOpRewritePattern;

  ::mlir::LogicalResult
  matchAndRewrite(::imex::ptensor::ExtractRTensorOp op,
                  ::mlir::PatternRewriter &rewriter) const override {
    auto loc = op.getLoc();
    // get input
    auto inpPtTyp =
        op.getInput().getType().dyn_cast<::imex::dist::DistTensorType>();
    if (!inpPtTyp) {
      return ::mlir::failure();
    }
    auto pTnsr =
        rewriter.create<::imex::dist::GetPTensorOp>(loc, op.getInput());
    rewriter.replaceOpWithNewOp<::imex::ptensor::ExtractRTensorOp>(
        op, inpPtTyp.getPTensorType().getRtensor(), pTnsr);
    return ::mlir::success();
  }
};

/// Rewriting ::imex::ptensor::ARangeOp to get a distributed arange if
/// applicable. Create global, distributed output Tensor as defined by operands.
/// The local partition (e.g. a RankedTensor) are wrapped in a
/// non-distributed PTensor and re-applied to arange op.
/// op gets replaced with global DistTensor
struct DistARangeOpRWP : public RecOpRewritePattern<::imex::ptensor::ARangeOp> {
  using RecOpRewritePattern::RecOpRewritePattern;

  ::mlir::LogicalResult
  matchAndRewrite(::imex::ptensor::ARangeOp op,
                  ::mlir::PatternRewriter &rewriter) const override {
    auto loc = op.getLoc();
    // nothing to do if no team
    auto team = op.getTeam();
    if (!team)
      return ::mlir::failure();

    // get operands
    auto start = op.getStart();
    auto step = op.getStep();
    // compute global count (so we know the shape)
    auto count = createCountARange(rewriter, loc, start, op.getStop(), step);
    auto dtype = rewriter.getI64Type(); // FIXME
    auto i64Typ = rewriter.getI64Type();
    // result shape is 1d
    constexpr uint64_t rank = 1;
    auto gShpTnsr = rewriter.create<::mlir::tensor::EmptyOp>(
        loc, ::mlir::ArrayRef<::mlir::OpFoldResult>({count}), dtype);
    auto gShape = rewriter.create<::mlir::shape::ShapeOfOp>(loc, gShpTnsr);
    // so is the local shape
    llvm::SmallVector<mlir::Value> lShapeVVec(rank);
    // get info
    auto info = createDistInfo(loc, rewriter, rank, gShape, team);
    // get local shape
    auto lShapeVVec_mr = createGetLocalShape(loc, rewriter, info);
    auto zero = createIndex(loc, rewriter, 0);
    auto lSz = rewriter.create<::mlir::tensor::ExtractOp>(
        loc, i64Typ, lShapeVVec_mr, ::mlir::ValueRange({zero}));
    // get local offsets
    auto offsets = createGetLocalOffsets(loc, rewriter, info);
    // create start from offset
    auto off = rewriter.create<::mlir::tensor::ExtractOp>(
        loc, i64Typ, offsets, ::mlir::ValueRange({zero}));
    auto tmp =
        rewriter.create<::mlir::arith::MulIOp>(loc, off, step); // off * step
    start = rewriter.create<::mlir::arith::AddIOp>(
        loc, start, tmp); // start + (off * stride)
    // create stop
    auto tmp2 = rewriter.create<::mlir::arith::MulIOp>(
        loc, lSz, step); // step * lShape[0]
    auto stop = rewriter.create<::mlir::arith::AddIOp>(
        loc, start, tmp2); // start + (lShape[0] * stride)
    //  get type of local tensor
    ::llvm::ArrayRef<int64_t> lShape({-1});
    auto artype = ::imex::ptensor::PTensorType::get(
        rewriter.getContext(), ::mlir::RankedTensorType::get({-1}, dtype),
        false, false);
    // finally create local arange
    auto dmy = ::mlir::Value(); // createInt<1>(loc, rewriter, 0);
    auto arres = rewriter.create<::imex::ptensor::ARangeOp>(
        loc, artype, start, stop, step, op.getDevice(), dmy);
    rewriter.replaceOp(op, createMkTnsr(loc, rewriter, arres, info));
    return ::mlir::success();
  }
};

/// Rewrite ::imex::ptensor::EWBinOp to get a distributed ewbinop
/// if operands are distributed.
/// Create global, distributed output tensor with same shape as operands.
/// The local partitions of operands (e.g. RankedTensors) are wrapped in
/// non-distributed PTensors and re-applied to ewbinop.
/// op gets replaced with global DistTensor
struct DistEWBinOpRWP : public RecOpRewritePattern<::imex::ptensor::EWBinOp> {
  using RecOpRewritePattern::RecOpRewritePattern;

  ::mlir::LogicalResult
  matchAndRewrite(::imex::ptensor::EWBinOp op,
                  ::mlir::PatternRewriter &rewriter) const override {
    auto loc = op.getLoc();
    auto lhsDtTyp =
        op.getLhs().getType().dyn_cast<::imex::dist::DistTensorType>();
    auto rhsDtTyp =
        op.getRhs().getType().dyn_cast<::imex::dist::DistTensorType>();
    // return failure if wrong ops or not distributed
    if (!lhsDtTyp || !rhsDtTyp) {
      return ::mlir::failure();
    }

    // result shape
    auto gShapeARef = lhsDtTyp.getPTensorType().getRtensor().getShape();
    auto gShapeAttr = rewriter.getIndexVectorAttr(gShapeARef);
    auto gShape = rewriter.create<::mlir::shape::ConstShapeOp>(loc, gShapeAttr);
    // local ewb operands
    auto lLhs = createGetLocal(loc, rewriter, op.getLhs());
    auto lRhs = createGetLocal(loc, rewriter, op.getRhs());
    // return type same as lhs for now
    auto retPtTyp = lLhs.getType(); // FIXME
    auto ewbres = rewriter.create<::imex::ptensor::EWBinOp>(
        loc, retPtTyp, op.getOp(), lLhs, lRhs);
    // get the team and init our new dist tensor
    auto team = createTeamOf(loc, rewriter, op.getLhs());
    auto info = createDistInfo(loc, rewriter, 1, gShape, team);
    rewriter.replaceOp(op, createMkTnsr(loc, rewriter, ewbres, info));
    return ::mlir::success();
  }
};

/// Rewrite ::imex::ptensor::ReductionOp to get a distributed
/// reduction if operand is distributed.
/// Create global, distributed 0d output tensor.
/// The local partitions of operand (e.g. RankedTensors) is wrapped in
/// non-distributed PTensor and re-applied to reduction.
/// The result is then applied to a distributed allreduce.
/// op gets replaced with global DistTensor
struct DistReductionOpRWP
    : public RecOpRewritePattern<::imex::ptensor::ReductionOp> {
  using RecOpRewritePattern::RecOpRewritePattern;

  ::mlir::LogicalResult
  matchAndRewrite(::imex::ptensor::ReductionOp op,
                  ::mlir::PatternRewriter &rewriter) const override {
    // FIXME reduction over individual dimensions is not supported
    auto loc = op.getLoc();
    // get input
    auto inpDtTyp =
        op.getInput().getType().dyn_cast<::imex::dist::DistTensorType>();
    if (!inpDtTyp) {
      return ::mlir::failure();
    }

    // result shape is 0d
    auto gShapeAttr = rewriter.getIndexTensorAttr({});
    auto gShape = rewriter.create<::mlir::shape::ConstShapeOp>(loc, gShapeAttr);
    // Local reduction
    auto local = createGetLocal(loc, rewriter, op.getInput());
    // return type 0d with same dtype as input
    auto dtype = inpDtTyp.getPTensorType().getRtensor().getElementType();
    auto retPtTyp = ::imex::ptensor::PTensorType::get(
        rewriter.getContext(), ::mlir::RankedTensorType::get({}, dtype), false,
        false);
    auto redPTnsr = rewriter.create<::imex::ptensor::ReductionOp>(
        loc, retPtTyp, op.getOp(), local);
    // global reduction
    auto retRTnsr = createAllReduce(loc, rewriter, op.getOp(), redPTnsr);
    // get the team and init our new dist tensor
    auto team = createTeamOf(loc, rewriter, op.getInput());
    auto info = createDistInfo(loc, rewriter, 1, gShape, team);
    auto dmy = createInt<1>(loc, rewriter, 0);
    auto resPTnsr = rewriter.create<::imex::ptensor::MkPTensorOp>(
        loc, false, true, retRTnsr, dmy, team);
    rewriter.replaceOp(op, createMkTnsr(loc, rewriter, resPTnsr, info));
    return ::mlir::success();
  }
};

// *******************************
// ***** Pass infrastructure *****
// *******************************

// Lowering dist dialect by no-ops
struct PTensorDistPass : public ::imex::PTensorDistBase<PTensorDistPass> {

  PTensorDistPass() = default;

  void runOnOperation() override {
    ::mlir::FrozenRewritePatternSet patterns;
    insertPatterns<DistARangeOpRWP, DistEWBinOpRWP, DistReductionOpRWP,
                   DistExtractRTensorOpRWP>(getContext(), patterns);
    (void)::mlir::applyPatternsAndFoldGreedily(this->getOperation(), patterns);
  }
};

} // namespace

/// Populate the given list with patterns that eliminate Dist ops
void populatePTensorDistPatterns(::mlir::LLVMTypeConverter &converter,
                                 ::mlir::RewritePatternSet &patterns) {
  assert(false);
}

/// Create a pass to eliminate Dist ops
std::unique_ptr<::mlir::OperationPass<::mlir::func::FuncOp>>
createPTensorDistPass() {
  return std::make_unique<PTensorDistPass>();
}

} // namespace imex