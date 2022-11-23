//===- Utils.h - Utils for Dist dialect  -----------------------*- C++ -*-===//
//
// Copyright 2022 Intel Corporation
// Part of the IMEX Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
/// This file declares the utils for the dist dialect.
///
//===----------------------------------------------------------------------===//

#ifndef _DIST_UTILS_H_INCLUDED_
#define _DIST_UTILS_H_INCLUDED_

#include <imex/Utils/PassUtils.h>
#include <mlir/Dialect/MemRef/IR/MemRef.h>
#include <mlir/Dialect/Tensor/IR/Tensor.h>
#include <mlir/IR/Builders.h>
#include <mlir/IR/BuiltinOps.h>

#include <vector>

namespace imex {

/// get dyn-sized mlir::RankedTensorType for given rank and elType
inline auto getTensorType(::mlir::MLIRContext *ctxt, int64_t rank,
                          ::mlir::Type elType) {
  return ::mlir::RankedTensorType::get(std::vector<int64_t>(rank, -1),
                                       elType); //, layout);
}

/// create an empty RankedTensor with tiven shape and elType
inline auto createEmptyTensor(::mlir::OpBuilder &builder, ::mlir::Location loc,
                              ::mlir::Type elType, ::mlir::ValueRange shp) {
  return builder.create<::mlir::tensor::EmptyOp>(
      loc, getTensorType(builder.getContext(), shp.size(), elType), shp);
}

/// get dyn-sized mlir::RankedTensorType for given rank and elType
/// if strided==true make it a strided layout
inline auto getMemRefType(::mlir::MLIRContext *ctxt, int64_t rank,
                          ::mlir::Type elType, bool strided = true) {
  static auto dynStride = ::mlir::ShapedType::kDynamicStrideOrOffset;
  auto layout = ::mlir::StridedLayoutAttr::get(
      ctxt, dynStride, ::mlir::SmallVector<int64_t>(rank, dynStride));
  return ::mlir::MemRefType::get(std::vector<int64_t>(rank, -1), elType,
                                 strided ? layout
                                         : ::mlir::StridedLayoutAttr{});
}

/// Create a 1d MemRef alloc with given size and elType
inline auto createAllocMR(::mlir::OpBuilder &builder, ::mlir::Location loc,
                          ::mlir::Type elType, int64_t sz) {
  return builder.create<::mlir::memref::AllocOp>(
      loc, ::mlir::MemRefType::get({sz}, elType), builder.getI64IntegerAttr(8));
}

/// Create a 1d MemRef from given elements and elType
inline ::mlir::Value createMemRefFromElements(::mlir::OpBuilder &builder,
                                              ::mlir::Location loc,
                                              ::mlir::Type elType,
                                              ::mlir::ValueRange elts) {
  int64_t N = elts.size();
  auto mr = createAllocMR(builder, loc, elType, N);
  for (auto i = 0; i < N; ++i) {
    auto idx = createIndex(loc, builder, i);
    (void)builder.create<::mlir::memref::StoreOp>(loc, elts[i], mr, idx);
  }
  return mr;
}

} // namespace imex

#endif // _DIST_UTILS_H_INCLUDED_
