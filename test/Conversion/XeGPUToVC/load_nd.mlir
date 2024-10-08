// RUN: imex-opt -convert-xegpu-to-vc='enable-vc-intrinsic=true useRawSend=true' -cse %s | FileCheck %s --check-prefixes=CHECK,RAW
// RUN: imex-opt -convert-xegpu-to-vc='enable-vc-intrinsic=true useRawSend=false' -cse  %s | FileCheck %s --check-prefixes=CHECK,LSC
module @gemm attributes {gpu.container_module} {
  gpu.module @test_kernel {

    // CHECK: gpu.func @test_load_nd_0(%[[arg0:.*]]: memref<8x16xf16>) kernel attributes {VectorComputeFunctionINTEL, spirv.entry_point_abi = #spirv.entry_point_abi<>} {
    gpu.func @test_load_nd_0(%arg0: memref<8x16xf16>) kernel attributes {VectorComputeFunctionINTEL, spirv.entry_point_abi = #spirv.entry_point_abi<>}{
      // CHECK: %cst = arith.constant dense<0> : vector<4xi64>
      // CHECK: %intptr = memref.extract_aligned_pointer_as_index %arg0 : memref<8x16xf16> -> index
      // CHECK: %0 = arith.index_castui %intptr : index to i64
      // CHECK: %1 = vector.insert %0, %cst [0] : i64 into vector<4xi64>
      // CHECK: %2 = vector.bitcast %1 : vector<4xi64> to vector<8xi32>
      // CHECK: %c31_i32 = arith.constant 31 : i32
      // CHECK: %c7_i32 = arith.constant 7 : i32
      // CHECK: %3 = vector.insert %c31_i32, %2 [2] : i32 into vector<8xi32>
      // CHECK: %4 = vector.insert %c7_i32, %3 [3] : i32 into vector<8xi32>
      // CHECK: %5 = vector.insert %c31_i32, %4 [4] : i32 into vector<8xi32>
      // CHECK: %c0_i32 = arith.constant 0 : i32
      // CHECK: %6 = vector.insert %c0_i32, %5 [5] : i32 into vector<8xi32>
      // CHECK: %7 = vector.insert %c0_i32, %6 [6] : i32 into vector<8xi32>
      // CHECK: %c1807_i32 = arith.constant 1807 : i32
      %0 = xegpu.create_nd_tdesc %arg0[0, 0] : memref<8x16xf16> -> !xegpu.tensor_desc<8x16xf16>

      //RAW: %8 = vector.insert %c1807_i32, %7 [7] : i32 into vector<8xi32>
      //RAW: %c0_i8 = arith.constant 0 : i8
      //RAW: %true = arith.constant true
      //RAW: %c1_i8 = arith.constant 1 : i8
      //RAW: %c4_i8 = arith.constant 4 : i8
      //RAW: %c15_i8 = arith.constant 15 : i8
      //RAW: %c37880323_i32 = arith.constant 37880323 : i32
      //RAW: %cst_0 = arith.constant dense<0> : vector<64xi32>
      //RAW: %9 = func.call @llvm.genx.raw.send2.v64i32.i1.v8i32(%c0_i8, %c0_i8, %true, %c1_i8, %c4_i8, %c15_i8, %c0_i32, %c37880323_i32, %8, %cst_0) : (i8, i8, i1, i8, i8, i8, i32, i32, vector<8xi32>, vector<64xi32>) -> vector<64xi32>

      //LSC: %8 = vector.insert %c1807_i32, %7 [7] : i32 into vector<8xi32>
      //LSC: %true = arith.constant true
      //LSC: %c0_i8 = arith.constant 0 : i8
      //LSC: %c2_i8 = arith.constant 2 : i8
      //LSC: %c1_i8 = arith.constant 1 : i8
      //LSC: %9 = vector.bitcast %8 : vector<8xi32> to vector<4xi64>
      //LSC: %10 = vector.extract %9[0] : i64 from vector<4xi64>
      //LSC: %c16_i32 = arith.constant 16 : i32
      //LSC: %c8_i32 = arith.constant 8 : i32
      //LSC: %11 = vector.extract %8[5] : i32 from vector<8xi32>
      //LSC: %12 = vector.extract %8[6] : i32 from vector<8xi32>
      //LSC: %13 = func.call @llvm.genx.lsc.load2d.stateless.v64i32.i1.i64(%true, %c0_i8, %c0_i8, %c2_i8, %c1_i8, %c1_i8, %c16_i32, %c8_i32, %c0_i8, %10, %c31_i32, %c7_i32, %c31_i32, %11, %12) : (i1, i8, i8, i8, i8, i8, i32, i32, i8, i64, i32, i32, i32, i32, i32) -> vector<64xi32>

      %1 = xegpu.load_nd %0 : !xegpu.tensor_desc<8x16xf16> -> vector<8x16xf16>
      // CHECK: gpu.return
      gpu.return
    }

    // CHECK: gpu.func @test_load_nd_1(%[[arg0:.*]]: memref<8x16xf16>) kernel attributes {VectorComputeFunctionINTEL, spirv.entry_point_abi = #spirv.entry_point_abi<>} {
    gpu.func @test_load_nd_1(%arg0: memref<8x16xf16>) kernel attributes {VectorComputeFunctionINTEL, spirv.entry_point_abi = #spirv.entry_point_abi<>}{
      //CHECK: %cst = arith.constant dense<0> : vector<4xi64>
      //CHECK: %intptr = memref.extract_aligned_pointer_as_index %arg0 : memref<8x16xf16> -> index
      //CHECK: %0 = arith.index_castui %intptr : index to i64
      //CHECK: %1 = vector.insert %0, %cst [0] : i64 into vector<4xi64>
      //CHECK: %2 = vector.bitcast %1 : vector<4xi64> to vector<8xi32>
      //CHECK: %c31_i32 = arith.constant 31 : i32
      //CHECK: %c7_i32 = arith.constant 7 : i32
      //CHECK: %3 = vector.insert %c31_i32, %2 [2] : i32 into vector<8xi32>
      //CHECK: %4 = vector.insert %c7_i32, %3 [3] : i32 into vector<8xi32>
      //CHECK: %5 = vector.insert %c31_i32, %4 [4] : i32 into vector<8xi32>
      //CHECK: %c0_i32 = arith.constant 0 : i32
      //CHECK: %6 = vector.insert %c0_i32, %5 [5] : i32 into vector<8xi32>
      //CHECK: %7 = vector.insert %c0_i32, %6 [6] : i32 into vector<8xi32>
      //CHECK: %c1807_i32 = arith.constant 1807 : i32
      %0 = xegpu.create_nd_tdesc %arg0[0, 0] : memref<8x16xf16> -> !xegpu.tensor_desc<8x16xf16>

      //RAW: %8 = vector.insert %c1807_i32, %7 [7] : i32 into vector<8xi32>
      //RAW: %c0_i8 = arith.constant 0 : i8
      //RAW: %true = arith.constant true
      //RAW: %c1_i8 = arith.constant 1 : i8
      //RAW: %c4_i8 = arith.constant 4 : i8
      //RAW: %c15_i8 = arith.constant 15 : i8
      //RAW: %c37880451_i32 = arith.constant 37880451 : i32
      //RAW: %cst_0 = arith.constant dense<0> : vector<64xi32>
      //RAW: %9 = func.call @llvm.genx.raw.send2.v64i32.i1.v8i32(%c0_i8, %c0_i8, %true, %c1_i8, %c4_i8, %c15_i8, %c0_i32, %c37880451_i32, %8, %cst_0) : (i8, i8, i1, i8, i8, i8, i32, i32, vector<8xi32>, vector<64xi32>) -> vector<64xi32>

      //LSC: %8 = vector.insert %c1807_i32, %7 [7] : i32 into vector<8xi32>
      //LSC: %true = arith.constant true
      //LSC: %c0_i8 = arith.constant 0 : i8
      //LSC: %c2_i8 = arith.constant 2 : i8
      //LSC: %c1_i8 = arith.constant 1 : i8
      //LSC: %9 = vector.bitcast %8 : vector<8xi32> to vector<4xi64>
      //LSC: %10 = vector.extract %9[0] : i64 from vector<4xi64>
      //LSC: %c16_i32 = arith.constant 16 : i32
      //LSC: %c8_i32 = arith.constant 8 : i32
      //LSC: %11 = vector.extract %8[5] : i32 from vector<8xi32>
      //LSC: %12 = vector.extract %8[6] : i32 from vector<8xi32>
      //LSC: %13 = func.call @llvm.genx.lsc.load2d.stateless.v64i32.i1.i64(%true, %c0_i8, %c0_i8, %c2_i8, %c1_i8, %c1_i8, %c16_i32, %c8_i32, %c1_i8, %10, %c31_i32, %c7_i32, %c31_i32, %11, %12) : (i1, i8, i8, i8, i8, i8, i32, i32, i8, i64, i32, i32, i32, i32, i32) -> vector<64xi32>
      %1 = xegpu.load_nd %0 <{packed}> : !xegpu.tensor_desc<8x16xf16> -> vector<4x16x2xf16>
      // CHECK: gpu.return
      gpu.return
    }


    // CHECK: gpu.func @test_load_nd_2(%[[arg0:.*]]: memref<8x16xf16>) kernel attributes {VectorComputeFunctionINTEL, spirv.entry_point_abi = #spirv.entry_point_abi<>} {
    gpu.func @test_load_nd_2(%arg0: memref<8x16xf16>) kernel attributes {VectorComputeFunctionINTEL, spirv.entry_point_abi = #spirv.entry_point_abi<>}{
      //CHECK: %cst = arith.constant dense<0> : vector<4xi64>
      //CHECK: %intptr = memref.extract_aligned_pointer_as_index %arg0 : memref<8x16xf16> -> index
      //CHECK: %0 = arith.index_castui %intptr : index to i64
      //CHECK: %1 = vector.insert %0, %cst [0] : i64 into vector<4xi64>
      //CHECK: %2 = vector.bitcast %1 : vector<4xi64> to vector<8xi32>
      //CHECK: %c31_i32 = arith.constant 31 : i32
      //CHECK: %c7_i32 = arith.constant 7 : i32
      //CHECK: %3 = vector.insert %c31_i32, %2 [2] : i32 into vector<8xi32>
      //CHECK: %4 = vector.insert %c7_i32, %3 [3] : i32 into vector<8xi32>
      //CHECK: %5 = vector.insert %c31_i32, %4 [4] : i32 into vector<8xi32>
      //CHECK: %c0_i32 = arith.constant 0 : i32
      //CHECK: %6 = vector.insert %c0_i32, %5 [5] : i32 into vector<8xi32>
      //CHECK: %7 = vector.insert %c0_i32, %6 [6] : i32 into vector<8xi32>
      //CHECK: %c1807_i32 = arith.constant 1807 : i32
      %0 = xegpu.create_nd_tdesc %arg0[0, 0] : memref<8x16xf16> -> !xegpu.tensor_desc<8x16xf16>

      //RAW: %8 = vector.insert %c1807_i32, %7 [7] : i32 into vector<8xi32>
      //RAW: %c0_i8 = arith.constant 0 : i8
      //RAW: %true = arith.constant true
      //RAW: %c1_i8 = arith.constant 1 : i8
      //RAW: %c4_i8 = arith.constant 4 : i8
      //RAW: %c15_i8 = arith.constant 15 : i8
      //RAW: %c37880323_i32 = arith.constant 37880323 : i32
      //RAW: %cst_0 = arith.constant dense<0> : vector<64xi32>
      //RAW: %9 = func.call @llvm.genx.raw.send2.v64i32.i1.v8i32(%c0_i8, %c0_i8, %true, %c1_i8, %c4_i8, %c15_i8, %c0_i32, %c37880323_i32, %8, %cst_0) : (i8, i8, i1, i8, i8, i8, i32, i32, vector<8xi32>, vector<64xi32>) -> vector<64xi32>

      //LSC: %8 = vector.insert %c1807_i32, %7 [7] : i32 into vector<8xi32>
      //LSC: %true = arith.constant true
      //LSC: %c0_i8 = arith.constant 0 : i8
      //LSC: %c2_i8 = arith.constant 2 : i8
      //LSC: %c1_i8 = arith.constant 1 : i8
      //LSC: %9 = vector.bitcast %8 : vector<8xi32> to vector<4xi64>
      //LSC: %10 = vector.extract %9[0] : i64 from vector<4xi64>
      //LSC: %c16_i32 = arith.constant 16 : i32
      //LSC: %c8_i32 = arith.constant 8 : i32
      //LSC: %11 = vector.extract %8[5] : i32 from vector<8xi32>
      //LSC: %12 = vector.extract %8[6] : i32 from vector<8xi32>
      //LSC: %13 = func.call @llvm.genx.lsc.load2d.stateless.v64i32.i1.i64(%true, %c0_i8, %c0_i8, %c2_i8, %c1_i8, %c1_i8, %c16_i32, %c8_i32, %c0_i8, %10, %c31_i32, %c7_i32, %c31_i32, %11, %12) : (i1, i8, i8, i8, i8, i8, i32, i32, i8, i64, i32, i32, i32, i32, i32) -> vector<64xi32>
      %1 = xegpu.load_nd %0 : !xegpu.tensor_desc<8x16xf16> -> vector<8x16xf16>
      // CHECK: gpu.return
      gpu.return
    }

    // CHECK: gpu.func @test_load_nd_1d_strided_memref(%[[arg0:.*]]: memref<32x32xf16, strided<[64, 1]>>) kernel attributes {VectorComputeFunctionINTEL, spirv.entry_point_abi = #spirv.entry_point_abi<>} {
    gpu.func @test_load_nd_1d_strided_memref(%arg0: memref<32x32xf16, strided<[64,1], offset: 0>>) kernel attributes {VectorComputeFunctionINTEL, spirv.entry_point_abi = #spirv.entry_point_abi<>}{
      //CHECK: %cst = arith.constant dense<0> : vector<4xi64>
      //CHECK: %intptr = memref.extract_aligned_pointer_as_index %arg0 : memref<32x32xf16, strided<[64, 1]>> -> index
      //CHECK: %c2 = arith.constant 2 : index
      //CHECK: %c0 = arith.constant 0 : index
      //CHECK: %0 = arith.muli %c0, %c2 : index
      //CHECK: %1 = arith.addi %intptr, %0 : index
      //CHECK: %c128 = arith.constant 128 : index
      //CHECK: %2 = arith.muli %c0, %c128 : index
      //CHECK: %3 = arith.addi %1, %2 : index
      //CHECK: %4 = arith.index_castui %3 : index to i64
      //CHECK: %5 = vector.insert %4, %cst [0] : i64 into vector<4xi64>
      %tdesc_1d = xegpu.create_nd_tdesc %arg0[0, 0] : memref<32x32xf16, strided<[64,1], offset: 0>> -> !xegpu.tensor_desc<16xf16>

      //RAW: %6 = vector.bitcast %5 : vector<4xi64> to vector<8xi32>
      //RAW: %c0_i8 = arith.constant 0 : i8
      //RAW: %true = arith.constant true
      //RAW: %c1_i8 = arith.constant 1 : i8
      //RAW: %c2_i8 = arith.constant 2 : i8
      //RAW: %c15_i8 = arith.constant 15 : i8
      //RAW: %c0_i32 = arith.constant 0 : i32
      //RAW: %c37926784_i32 = arith.constant 37926784 : i32
      //RAW: %7 = func.call @llvm.genx.raw.send2.v4i64.i1.v8i32(%c0_i8, %c0_i8, %true, %c1_i8, %c2_i8, %c15_i8, %c0_i32, %c37926784_i32, %6, %cst) : (i8, i8, i1, i8, i8, i8, i32, i32, vector<8xi32>, vector<4xi64>) -> vector<4xi64>

      //LSC: %6 = vector.bitcast %5 : vector<4xi64> to vector<8xi32>
      //LSC: %true = arith.constant true
      //LSC: %c0_i8 = arith.constant 0 : i8
      //LSC: %7 = vector.bitcast %6 : vector<8xi32> to vector<4xi64>
      //LSC: %8 = vector.extract %7[0] : i64 from vector<4xi64>
      //LSC: %c1_i16 = arith.constant 1 : i16
      //LSC: %c0_i32 = arith.constant 0 : i32
      //LSC: %c4_i8 = arith.constant 4 : i8
      //LSC: %c2_i8 = arith.constant 2 : i8
      //LSC: %9 = func.call @llvm.genx.lsc.load.stateless.v4i64.i1.i64(%true, %c0_i8, %c0_i8, %c0_i8, %c1_i16, %c0_i32, %c4_i8, %c4_i8, %c2_i8, %c0_i8, %8, %c0_i32) : (i1, i8, i8, i8, i16, i32, i8, i8, i8, i8, i64, i32) -> vector<4xi64>
      %load_1d = xegpu.load_nd %tdesc_1d  : !xegpu.tensor_desc<16xf16> -> vector<16xf16>
      gpu.return
    }

    // CHECK: gpu.func @test_load_nd_2d_strided_memref(%[[arg0:.*]]: memref<32x32xf16, strided<[64, 1]>>) kernel attributes {VectorComputeFunctionINTEL, spirv.entry_point_abi = #spirv.entry_point_abi<>} {
    gpu.func @test_load_nd_2d_strided_memref(%arg0: memref<32x32xf16, strided<[64,1], offset: 0>>) kernel attributes {VectorComputeFunctionINTEL, spirv.entry_point_abi = #spirv.entry_point_abi<>}{
      //CHECK: %cst = arith.constant dense<0> : vector<4xi64>
      //CHECK: %intptr = memref.extract_aligned_pointer_as_index %arg0 : memref<32x32xf16, strided<[64, 1]>> -> index
      //CHECK: %0 = arith.index_castui %intptr : index to i64
      //CHECK: %1 = vector.insert %0, %cst [0] : i64 into vector<4xi64>
      //CHECK: %2 = vector.bitcast %1 : vector<4xi64> to vector<8xi32>
      //CHECK: %c63_i32 = arith.constant 63 : i32
      //CHECK: %c31_i32 = arith.constant 31 : i32
      //CHECK: %c127_i32 = arith.constant 127 : i32
      //CHECK: %3 = vector.insert %c63_i32, %2 [2] : i32 into vector<8xi32>
      //CHECK: %4 = vector.insert %c31_i32, %3 [3] : i32 into vector<8xi32>
      //CHECK: %5 = vector.insert %c127_i32, %4 [4] : i32 into vector<8xi32>
      //CHECK: %c0_i32 = arith.constant 0 : i32
      //CHECK: %6 = vector.insert %c0_i32, %5 [5] : i32 into vector<8xi32>
      //CHECK: %7 = vector.insert %c0_i32, %6 [6] : i32 into vector<8xi32>
      //CHECK: %c1807_i32 = arith.constant 1807 : i32
      %tdesc_2d = xegpu.create_nd_tdesc %arg0[0, 0] : memref<32x32xf16, strided<[64,1], offset: 0>> -> !xegpu.tensor_desc<8x16xf16>

      //RAW: %8 = vector.insert %c1807_i32, %7 [7] : i32 into vector<8xi32>
      //RAW: %c0_i8 = arith.constant 0 : i8
      //RAW: %true = arith.constant true
      //RAW: %c1_i8 = arith.constant 1 : i8
      //RAW: %c4_i8 = arith.constant 4 : i8
      //RAW: %c15_i8 = arith.constant 15 : i8
      //RAW: %c37880323_i32 = arith.constant 37880323 : i32
      //RAW: %cst_0 = arith.constant dense<0> : vector<64xi32>
      //RAW: %9 = func.call @llvm.genx.raw.send2.v64i32.i1.v8i32(%c0_i8, %c0_i8, %true, %c1_i8, %c4_i8, %c15_i8, %c0_i32, %c37880323_i32, %8, %cst_0) : (i8, i8, i1, i8, i8, i8, i32, i32, vector<8xi32>, vector<64xi32>) -> vector<64xi32>

      //LSC: %8 = vector.insert %c1807_i32, %7 [7] : i32 into vector<8xi32>
      //LSC: %true = arith.constant true
      //LSC: %c0_i8 = arith.constant 0 : i8
      //LSC: %c2_i8 = arith.constant 2 : i8
      //LSC: %c1_i8 = arith.constant 1 : i8
      //LSC: %9 = vector.bitcast %8 : vector<8xi32> to vector<4xi64>
      //LSC: %10 = vector.extract %9[0] : i64 from vector<4xi64>
      //LSC: %c16_i32 = arith.constant 16 : i32
      //LSC: %c8_i32 = arith.constant 8 : i32
      //LSC: %11 = vector.extract %8[5] : i32 from vector<8xi32>
      //LSC: %12 = vector.extract %8[6] : i32 from vector<8xi32>
      //LSC: %13 = func.call @llvm.genx.lsc.load2d.stateless.v64i32.i1.i64(%true, %c0_i8, %c0_i8, %c2_i8, %c1_i8, %c1_i8, %c16_i32, %c8_i32, %c0_i8, %10, %c63_i32, %c31_i32, %c127_i32, %11, %12) : (i1, i8, i8, i8, i8, i8, i32, i32, i8, i64, i32, i32, i32, i32, i32) -> vector<64xi32>
      %load_2d = xegpu.load_nd %tdesc_2d : !xegpu.tensor_desc<8x16xf16> -> vector<8x16xf16>
      gpu.return
    }
  }
}
