// RUN: imex-opt %s | sed s/true\>/1\>/g | FileCheck %s
// Verify the printed output can be parsed.
// RUN: imex-opt %s | sed s/true\>/1\>/g | imex-opt | FileCheck %s
// RUN: imex-opt -mlir-print-op-generic %s |  sed s/true\>/1\>/g | imex-opt | FileCheck %s

// FIXME sed above, for using 1 instead of true

// -----
func.func @test_extract_slice(%arg0: !ptensor.ptensor<tensor<?xi64>>) -> !ptensor.ptensor<tensor<?xi64>> {
    %c0 = arith.constant 0 : index
    %c3 = arith.constant 3 : index
    %0 = ptensor.extract_slice %arg0[%c0][%c3][%c3] : !ptensor.ptensor<tensor<?xi64>> to !ptensor.ptensor<tensor<?xi64>>
    return %0 : !ptensor.ptensor<tensor<?xi64>>
}
// CHECK-LABEL: @test_extract_slice
// CHECK-NEXT: [[C0:%.*]] = arith.constant
// CHECK-NEXT: [[C1:%.*]] = arith.constant
// CHECK-NEXT: ptensor.extract_slice %arg0[[[C0]]] [[[C1]]] [[[C1]]] : !ptensor.ptensor<tensor<?xi64>> to !ptensor.ptensor<tensor<?xi64>>

// -----
func.func @test_arange(%arg0: si64, %arg1: si64, %arg2: si64) -> !ptensor.ptensor<tensor<?xi64>> {
    %0 = "ptensor.arange"(%arg0, %arg1, %arg2) : (si64, si64, si64) -> !ptensor.ptensor<tensor<?xi64>>
    return %0 : !ptensor.ptensor<tensor<?xi64>>
}
// CHECK-LABEL: @test_arange
// CHECK-NEXT: "ptensor.arange"(%arg0, %arg1, %arg2) : (si64, si64, si64) -> !ptensor.ptensor<tensor<?xi64>>

// -----
func.func @test_ewbin(%arg0: !ptensor.ptensor<tensor<?xi64>>) -> !ptensor.ptensor<tensor<?xi64>> {
    %0 = "ptensor.ewbin"(%arg0, %arg0) {op = 0 : i32} : (!ptensor.ptensor<tensor<?xi64>>, !ptensor.ptensor<tensor<?xi64>>) -> !ptensor.ptensor<tensor<?xi64>>
    return %0 : !ptensor.ptensor<tensor<?xi64>>
}
// CHECK-LABEL: @test_ewbin
// CHECK-NEXT: "ptensor.ewbin"(%arg0, %arg0) {op = 0 : i32} : (!ptensor.ptensor<tensor<?xi64>>, !ptensor.ptensor<tensor<?xi64>>) -> !ptensor.ptensor<tensor<?xi64>>

// -----
func.func @test_reduction(%arg0: !ptensor.ptensor<tensor<?xi64>>) -> si64 {
    %0 = "ptensor.reduction"(%arg0) {op = 4 : i32} : (!ptensor.ptensor<tensor<?xi64>>) -> !ptensor.ptensor<tensor<si64>>
    %1 = builtin.unrealized_conversion_cast %0 : !ptensor.ptensor<tensor<si64>> to si64
    return %1 : si64
}
// CHECK-LABEL: @test_reduction
// CHECK-NEXT: "ptensor.reduction"(%arg0) {op = 4 : i32} : (!ptensor.ptensor<tensor<?xi64>>) -> !ptensor.ptensor<tensor<si64>>