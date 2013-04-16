/***
  *  Project:
  *
  *  File: ff_num_gpu_kernels.cuh
  *  Created: Apr 11, 2013
  *  Modified: Sat 13 Apr 2013 04:28:57 PM PDT
  *
  *  Author: Abhinav Sarje <asarje@lbl.gov>
  */


	/***
	 * special case when b_nqx == 1
	 */
	__global__ void form_factor_kernel_fused_nqx1(
						const float_t* __restrict__ qx, const float_t* __restrict__ qy,
						const cucomplex_t* __restrict__ qz,
						const float_t* __restrict__ shape_def, const short int* __restrict__ axes,
						const unsigned int curr_nqx, const unsigned int curr_nqy,
						const unsigned int curr_nqz, const unsigned int curr_num_triangles,
						const unsigned int b_nqx, const unsigned int b_nqy,
						const unsigned int b_nqz, const unsigned int b_num_triangles,
						const unsigned int ib_x, const unsigned int ib_y,
						const unsigned int ib_z, const unsigned int ib_t,
						cucomplex_t* __restrict__ ff) {
		unsigned int i_y = blockDim.x * blockIdx.x + threadIdx.x;
		unsigned int i_z = blockDim.y * blockIdx.y + threadIdx.y;
		unsigned int i_thread = blockDim.x * threadIdx.y + threadIdx.x;
		unsigned int num_threads = blockDim.x * blockDim.y;

		// sizes are:	shared_shape_def = T_PROP_SIZE_ * blockDim.x
		// 				shared_qx = curr_nqx	// the whole qx
		// 				shared_qy = blockDim.y
		// 				shared_qz = blockDim.z
		// reversed to fix alignment:
		float_t *shared_shape_def = (float_t*) dynamic_shared;
		cucomplex_t *shared_qz = (cucomplex_t*) &shared_shape_def[T_PROP_SIZE_ * curr_num_triangles];
		float_t *shared_qy = (float_t*) &shared_qz[blockDim.y];
		float_t *shared_qx = (float_t*) &shared_qy[blockDim.x];

		unsigned int i_shared, base_offset, num_loads;

		// load triangles
		unsigned int shape_def_size = T_PROP_SIZE_ * curr_num_triangles;
		num_loads = __float2int_ru(__fdividef(__int2float_ru(shape_def_size), num_threads));
		//asm("{\n\t"
		//		" .reg .f32 r1;\n\t"
		//		" .reg .f32 r2;\n\t"
		//		" .reg .f32 r3;\n\t"
		//		" cvt.rp.f32.u32 r1, %1;\n\t"
		//		" cvt.rp.f32.u32 r2, %2;\n\t"
		//		" div.approx.f32 r3, r1, r2;\n\t"
		//		" cvt.rpi.u32.f32 %0, r3;\n\t"
		//	"}"
		//	: "=r"(num_loads) : "r"(shape_def_size), "r"(num_threads));
		base_offset = T_PROP_SIZE_ * b_num_triangles * ib_t;
		for(int l = 0; l < num_loads; ++ l) {
			i_shared = num_threads * l + i_thread;
			if(i_shared < shape_def_size) shared_shape_def[i_shared] = shape_def[base_offset + i_shared];
		} // for

		// load qz
		unsigned int i_qz = b_nqz * ib_z + i_z;
		if(threadIdx.x == 0 && i_z < curr_nqz)
			shared_qz[threadIdx.y] = qz[i_qz];	// M: spread about access ...

		// load qy
		unsigned int i_qy = b_nqy * ib_y + i_y;
		if(threadIdx.y == 0 && i_y < curr_nqy)
			shared_qy[threadIdx.x] = qy[i_qy];	// M: spread about access ...

		// load qx
		if(i_thread == 0) shared_qx[0] = qx[ib_x];

		__syncthreads();	// sync to make sure all data is loaded and available

		cucomplex_t ff_tot = make_cuC((float_t) 0.0, (float_t) 0.0);
		if(i_y < curr_nqy && i_z < curr_nqz) {
			float_t temp_x = shared_qx[0];
			float_t temp_y = shared_qy[threadIdx.x];
			float_t qy2 = temp_y * temp_y;
			cucomplex_t temp_z = shared_qz[threadIdx.y];

			float_t qxy2 = fmaf(temp_x, temp_x, qy2);
			cucomplex_t q2 = cuCsqr(temp_z) + qxy2;

			// TODO: try dynamic parallelism to parallelize this on k20x ...
			#pragma unroll 16
			for(int i_t = 0; i_t < curr_num_triangles; ++ i_t) {
				unsigned int shape_off = T_PROP_SIZE_ * i_t;
				//float_t s = shared_shape_def[shape_off];
				//float_t nx = shared_shape_def[shape_off + 1];
				//float_t ny = shared_shape_def[shape_off + 2];
				//float_t nz = shared_shape_def[shape_off + 3];
				//float_t x = shared_shape_def[shape_off + 4];
				//float_t y = shared_shape_def[shape_off + 5];
				//float_t z = shared_shape_def[shape_off + 6];
				float_t s, nx, ny, nz, x, y, z;
				#ifndef DOUBLEP
				asm("{\n"
						" .reg .s64 rd1;\n"
						" .reg .s64 rd2;\n"
						" .reg .s64 rd3;\n"
						" .reg .s64 rd4;\n"
						" .reg .s64 rd5;\n"
						" .reg .s64 rd6;\n"
						" .reg .s64 rd7;\n"
						" mul.wide.u32 rd1, %7, 4;\n"
						" add.s64 rd2, rd1, 4;\n"
						" add.s64 rd3, rd1, 8;\n"
						" add.s64 rd4, rd1, 12;\n"
						" add.s64 rd5, rd1, 16;\n"
						" add.s64 rd6, rd1, 20;\n"
						" add.s64 rd7, rd1, 24;\n"
						" ld.shared.f32 %0, [rd1];\n"
						" ld.shared.f32 %1, [rd2];\n"
						" ld.shared.f32 %2, [rd3];\n"
						" ld.shared.f32 %3, [rd4];\n"
						" ld.shared.f32 %4, [rd5];\n"
						" ld.shared.f32 %5, [rd6];\n"
						" ld.shared.f32 %6, [rd7];\n"
					"}\n"
					: "=f"(s), "=f"(nx), "=f"(ny), "=f"(nz), "=f"(x), "=f"(y), "=f"(z)
					: "r"(shape_off), "l"(shared_shape_def)
				   );
				#else
				asm("{\n"
						" .reg .s64 rd1;\n"
						" .reg .s64 rd2;\n"
						" .reg .s64 rd3;\n"
						" .reg .s64 rd4;\n"
						" .reg .s64 rd5;\n"
						" .reg .s64 rd6;\n"
						" .reg .s64 rd7;\n"
						" mul.wide.u32 rd1, %7, 8;\n"
						" add.s64 rd2, rd1, 8;\n"
						" add.s64 rd3, rd1, 16;\n"
						" add.s64 rd4, rd1, 24;\n"
						" add.s64 rd5, rd1, 32;\n"
						" add.s64 rd6, rd1, 40;\n"
						" add.s64 rd7, rd1, 48;\n"
						" ld.shared.f64 %0, [rd1];\n"
						" ld.shared.f64 %1, [rd2];\n"
						" ld.shared.f64 %2, [rd3];\n"
						" ld.shared.f64 %3, [rd4];\n"
						" ld.shared.f64 %4, [rd5];\n"
						" ld.shared.f64 %5, [rd6];\n"
						" ld.shared.f64 %6, [rd7];\n"
					"}\n"
					: "=d"(s), "=d"(nx), "=d"(ny), "=d"(nz), "=d"(x), "=d"(y), "=d"(z)
					: "r"(shape_off), "l"(shared_shape_def)
				   );
				#endif

				float_t qyn = temp_y * ny;
				float_t qyt = temp_y * y;
				cucomplex_t qzn = temp_z * nz;
				cucomplex_t qzt = temp_z * z;

				cucomplex_t qt_d, qn_d;
				compute_qi_d(temp_x, nx, x, qyt, qyn, qzt, qzn, q2, qt_d, qn_d);

				ff_tot = ff_tot + compute_fq(s, qt_d, qn_d);
			} // for
			ff[curr_nqy * i_z + i_y] = ff_tot;
		} // if
	} // form_factor_kernel_fused_nqx1()


	/**
	 * Helper device functions
	 */

	/**
	 * For single precision
	 */

	__device__ __inline__ void compute_qi_d(float temp_x, float nx, float x, float qyt, float qyn,
											cuFloatComplex qzt, cuFloatComplex qzn, cuFloatComplex q2,
											cuFloatComplex& qt_d, cuFloatComplex& qn_d) {
		qt_d = fmaf(temp_x, x, qyt) + qzt;
		qn_d = cuCdivf((fmaf(temp_x, nx, qyn) + qzn), q2);
	} // compute_qi_d()


	__device__ __inline__ cuFloatComplex compute_fq(float s, cuFloatComplex qt_d, cuFloatComplex qn_d) {
		cuFloatComplex v1 = cuCmulf(qn_d, make_cuFloatComplex(__cosf(qt_d.x), __sinf(qt_d.x)));
		float v2 = s * __expf(qt_d.y);
		return v1 * v2;
	} // compute_fq()


	__device__ __inline__ void compute_z(cuFloatComplex temp_z, float nz, float z,
				cuFloatComplex& qz2, cuFloatComplex& qzn, cuFloatComplex& qzt) {
		//qz2 = cuCmulf(temp_z, temp_z);
		//qzn = cuCmulf(temp_z, make_cuFloatComplex(nz, 0.0f));
		//qzt = cuCmulf(temp_z, make_cuFloatComplex(z, 0.0f));
		qz2 = cuCsqr(temp_z);
		qzn = temp_z * nz;
		qzt = temp_z * z;
	} // compute_z()


	__device__ __inline__ void compute_x(float temp_x, float qy2, cuFloatComplex qz2, float nx, float qyn,
				cuFloatComplex qzn, float x, float qyt,	cuFloatComplex qzt,
				cuFloatComplex& qn_d, cuFloatComplex& qt_d) {
		//cuFloatComplex q2 = cuCaddf(make_cuFloatComplex(fmaf(temp_x, temp_x, qy2), 0.0f), qz2);
		//qn_d = cuCdivf(cuCaddf(make_cuFloatComplex(temp_x * nx, 0.0f),
		//						cuCaddf(make_cuFloatComplex(qyn, 0.0f), qzn)), q2);
		//qt_d = cuCaddf(make_cuFloatComplex(fmaf(temp_x, x, qyt), 0.0f), qzt);
		cuFloatComplex q2 = fmaf(temp_x, temp_x, qy2) + qz2;
		qt_d = fmaf(temp_x, x, qyt) + qzt;
		qn_d = cuCdivf((fmaf(temp_x, nx, qyn) + qzn), q2);
	} // compute_x()


	/**
	 * For double precision
	 */

	__device__ __inline__ void compute_qi_d(double temp_x, double nx, double x, double qyt, double qyn,
											cuDoubleComplex qzt, cuDoubleComplex qzn, cuDoubleComplex q2,
											cuDoubleComplex& qt_d, cuDoubleComplex& qn_d) {
		qt_d = fma(temp_x, x, qyt) + qzt;
		qn_d = cuCdiv((fma(temp_x, nx, qyn) + qzn), q2);
	} // compute_qi_d()


	__device__ __inline__ cuDoubleComplex compute_fq(double s, cuDoubleComplex qt_d, cuDoubleComplex qn_d) {
		cuDoubleComplex v1 = cuCmul(qn_d, make_cuDoubleComplex(__cos(qt_d.x), __sin(qt_d.x)));
		double v2 = s * __exp(qt_d.y);
		//return cuCmul(v1, make_cuDoubleComplex(v2, 0.0));
		return v1 * v2;
	} // compute_fq()


	__device__ __inline__ void compute_z(cuDoubleComplex temp_z, double nz, double z,
				cuDoubleComplex& qz2, cuDoubleComplex& qzn, cuDoubleComplex& qzt) {
		//qz2 = cuCmul(temp_z, temp_z);
		//qzn = cuCmul(temp_z, make_cuDoubleComplex(nz, 0.0));
		//qzt = cuCmul(temp_z, make_cuDoubleComplex(z, 0.0));
		qz2 = cuCsqr(temp_z);
		qzn = temp_z * nz;
		qzt = temp_z * z;
	} // compute_z()


	__device__ __inline__ void compute_x(double temp_x, double qy2, cuDoubleComplex qz2, double nx, double qyn,
				cuDoubleComplex qzn, double x, double qyt,	cuDoubleComplex qzt,
				cuDoubleComplex& qn_d, cuDoubleComplex& qt_d) {
		//cuDoubleComplex q2 = cuCadd(make_cuDoubleComplex(fma(temp_x, temp_x, qy2), 0.0), qz2);
		//qn_d = cuCdiv(cuCadd(make_cuDoubleComplex(temp_x * nx, 0.0),
		//						cuCadd(make_cuDoubleComplex(qyn, 0.0), qzn)), q2);
		//qt_d = cuCadd(make_cuDoubleComplex(fma(temp_x, x, qyt), 0.0), qzt);
		cuDoubleComplex q2 = fma(temp_x, temp_x, qy2) + qz2;
		qt_d = fma(temp_x, x, qyt) + qzt;
		qn_d = cuCdiv((fma(temp_x, nx, qyn) + qzn), q2);
	} // compute_x()

