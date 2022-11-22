// RUN: %python_executable %imex_runner -i %s --pass-pipeline-file=%p/ptensor.pp -e main -entry-point-result=void --shared-libs=%mlir_c_runner_utils --shared-libs=%mlir_runner_utils | FileCheck %s

module {
    func.func private @printMemrefI64(%ptr : tensor<*xi64>)
    func.func @main() {
        %c0 = arith.constant 0 : i64
        %c1 = arith.constant 1 : i64
        %c2 = arith.constant 2 : i64
        %c5 = arith.constant 5 : i64
        %c10 = arith.constant 10 : i64
        %i1 = arith.constant 1 : index
        %i2 = arith.constant 2 : index

        %3 = "ptensor.arange"(%c0, %c10, %c2, %c0, %c0) : (i64, i64, i64, i64, i64) -> !ptensor.ptensor<1 x i64>
        %4 = builtin.unrealized_conversion_cast %3 : !ptensor.ptensor<1 x i64> to memref<?xi64>
        %5 = bufferization.to_tensor %4 : memref<?xi64>
        %6 = tensor.cast %5 : tensor<?xi64> to tensor<*xi64>
        call @printMemrefI64(%6) : (tensor<*xi64>) -> ()
        // CHECK: Unranked Memref base@ = {{(0x)?[-9a-f]*}}
        // CHECK-SAME: rank = 1 offset = 0 sizes = [5] strides = [1] data =
        // CHECK-NEXT: [0,  2,  4,  6,  8]

        // %13 = "ptensor.arange"(%c0, %c10, %c2, %c0, %c10) : (i64, i64, i64, i64, i64) -> !ptensor.ptensor<1 x i64>
        // %14 = "ptensor.extract_tensor"(%13) : (!ptensor.ptensor<1 x i64>) -> tensor<?xi64>
        // %15 = tensor.cast %14 : tensor<?xi64> to tensor<*xi64>
        // call @printMemrefI64(%15) : (tensor<*xi64>) -> ()
        // _CHECK: Unranked Memref base@ = {{(0x)?[-9a-f]*}}
        // _CHECK-SAME: rank = 1 offset = 0 sizes = [5] strides = [1] data =
        // _CHECK-NEXT: [0,  2,  4,  6,  8]

        %20 = ptensor.extract_slice %3[%i1][%i2][%i2] : !ptensor.ptensor<1 x i64> to !ptensor.ptensor<1 x i64>
        %21 = builtin.unrealized_conversion_cast %20 : !ptensor.ptensor<1 x i64> to memref<?xi64>
        %22 = bufferization.to_tensor %21 : memref<?xi64>
        %23 = tensor.cast %22 : tensor<?xi64> to tensor<*xi64>
        call @printMemrefI64(%23) : (tensor<*xi64>) -> ()
        // CHECK: Unranked Memref base@ = {{(0x)?[-9a-f]*}}
        // CHECK-SAME: rank = 1 offset = 1 sizes = [2] strides = [2] data =
        // CHECK-NEXT: [2, 6]


        %30 = "ptensor.arange"(%c0, %c2, %c1, %c0, %c0) : (i64, i64, i64, i64, i64) -> !ptensor.ptensor<1 x i64>
        ptensor.insert_slice %30 into %3[%i1] [%i2] [%i2] : !ptensor.ptensor<1 x i64> into !ptensor.ptensor<1 x i64>
        // %31 = "ptensor.extract_tensor"(%30) : (!ptensor.ptensor<1 x i64>) -> tensor<?xi64>
        // %32 = tensor.cast %31 : tensor<?xi64> to tensor<*xi64>
        call @printMemrefI64(%6) : (tensor<*xi64>) -> ()
        // CHECK: Unranked Memref base@ = {{(0x)?[-9a-f]*}}
        // CHECK-SAME: rank = 1 offset = 0 sizes = [5] strides = [1] data =
        // CHECK-NEXT: [0,  0,  4,  1,  8]

        return
    }
}
