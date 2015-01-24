/**
 *  Project: HipGISAXS (High-Performance GISAXS)
 *
 *  File: ff_ana_prism6_gpu.cu
 *  Created: Oct 16, 2012
 *
 *  Author: Abhinav Sarje <asarje@lbl.gov>
 *  Developers: Slim Chourou <stchourou@lbl.gov>
 *              Abhinav Sarje <asarje@lbl.gov>
 *              Elaine Chan <erchan@lbl.gov>
 *              Alexander Hexemer <ahexemer@lbl.gov>
 *              Xiaoye Li <xsli@lbl.gov>
 *
 *  Licensing: The HipGISAXS software is only available to be downloaded and
 *  used by employees of academic research institutions, not-for-profit
 *  research laboratories, or governmental research facilities. Please read the
 *  accompanying LICENSE file before downloading the software. By downloading
 *  the software, you are agreeing to be bound by the terms of this
 *  NON-COMMERCIAL END USER LICENSE AGREEMENT.
 */

#include <iostream>
#include <fstream>
#include <complex>
#include <cuComplex.h>
#include <stdio.h>

#include <ff/gpu/ff_ana_gpu.cuh>
#include <common/enums.hpp>
#include <common/constants.hpp>
#include <numerics/gpu/cu_complex_numeric.cuh>
#include <utils/gpu/cu_utilities.cuh>


namespace hig {

  extern __constant__ float_t tau_d;
  extern __constant__ float_t eta_d;
  extern __constant__ float_t transvec_d[3];
  extern __constant__ float_t rot_d[9];

  /** Form Factor of Prism6:
   *  ff = It is complicated ...
   */
  __device__  __inline__ cucomplex_t FormFactorPrism6(cucomplex_t qx, cucomplex_t qy, cucomplex_t qz, 
          float_t length, float_t height){

    cucomplex_t tmp = 3. * qy * qy - qx * qx;
    if (cuCabsolute(tmp) < 1.0E-20)
        return make_cuC(ZERO, ZERO);

    // define complex units
    const cucomplex_t P_J = make_cuC(ZERO, ONE);
    const cucomplex_t N_J = make_cuC(ZERO, NEG_ONE);
    const float_t sqrt3 = 1.732050808;

    float_t L = 0.5 * length;
    float_t H = 0.5 * height;

    cucomplex_t t1 = 4. * sqrt3 / tmp;
    cucomplex_t t2 = qy * qy * L * L * cuCsinc(qx * L / sqrt3) * cuCsinc(qy * L);
    cucomplex_t t3 = cuCcos(2 * qx * L / sqrt3);
    cucomplex_t t4 = cuCcos(qy * L) * cuCcos(qx * L / sqrt3);
    cucomplex_t t5 = cuCsinc(qz * H) * cuCexp(P_J * qz * H);
    return (t1 * (t2 + t3 - t4) * t5);
  }
 
  __global__ void ff_prism6_kernel (unsigned int nqy, unsigned int nqz, 
          float_t * qx, float_t * qy, cucomplex_t * qz, cucomplex_t * ff,
          int nx, float_t * x, float_t * distr_x,
          int ny, float_t * y, float_t * distr_y) {

    int i_z = blockDim.x * blockIdx.x + threadIdx.x;
    if (i_z < nqz){
      int i_y = i_z % nqy;
      cucomplex_t c_neg_unit = make_cuC(ZERO, NEG_ONE);
      cucomplex_t mqx, mqy, mqz;
      compute_meshpoints(qx[i_y], qy[i_y], qz[i_z], rot_d, mqx, mqy, mqz);
      cucomplex_t temp_ff = make_cuC(ZERO, ZERO);
      for (int i = 0; i < nx; i++){
        for (int j = 0; j < ny; j++){
          float_t wght = distr_x[i] * distr_y[j];
          temp_ff = temp_ff + FormFactorPrism6(mqx, mqy, mqz, x[i], y[j]) * wght;
        }
      }
      cucomplex_t temp1 = transvec_d[0] * mqx + transvec_d[1] * mqy + transvec_d[2] * mqz;
      ff[i_z] =  temp_ff * cuCexpi(temp1);
    }
  } // ff_prism6_kernel()

   
  bool AnalyticFormFactorG::compute_prism6(const float_t tau, const float_t eta,
                  const std::vector<float_t>& x,
                  const std::vector<float_t>& distr_x,
                  const std::vector<float_t>& y,
                  const std::vector<float_t>& distr_y,
                  const float_t* rot_h, const std::vector<float_t>& transvec,
                  std::vector<complex_t>& ff) {
    unsigned int n_x = x.size(), n_distr_x = distr_x.size();
    unsigned int n_y = y.size(), n_distr_y = distr_y.size();

    const float_t *x_h = x.empty() ? NULL : &*x.begin();
    const float_t *distr_x_h = distr_x.empty() ? NULL : &*distr_x.begin();
    const float_t *y_h = y.empty() ? NULL : &*y.begin();
    const float_t *distr_y_h = distr_y.empty() ? NULL : &*distr_y.begin();
    float_t transvec_h[3] = {transvec[0], transvec[1], transvec[2]};

    // construct device buffers
    float_t *x_d, *distr_x_d;
    float_t *y_d, *distr_y_d;

    cudaMalloc((void**) &x_d, n_x * sizeof(float_t));
    cudaMalloc((void**) &distr_x_d, n_distr_x * sizeof(float_t));
    cudaMalloc((void**) &y_d, n_y * sizeof(float_t));
    cudaMalloc((void**) &distr_y_d, n_distr_y * sizeof(float_t));

    // copy data to device buffers
    cudaMemcpy(x_d, x_h, n_x * sizeof(float_t), cudaMemcpyHostToDevice);
    cudaMemcpy(y_d, y_h, n_y * sizeof(float_t), cudaMemcpyHostToDevice);
    cudaMemcpy(distr_x_d, distr_x_h, n_distr_x * sizeof(float_t), cudaMemcpyHostToDevice);
    cudaMemcpy(distr_y_d, distr_y_h, n_distr_y * sizeof(float_t), cudaMemcpyHostToDevice);

    //run_init(rot_h, transvec);
    cudaMemcpyToSymbol(tau_d, &tau, sizeof(float_t), 0, cudaMemcpyHostToDevice);
    cudaMemcpyToSymbol(eta_d, &eta, sizeof(float_t), 0, cudaMemcpyHostToDevice);
    cudaMemcpyToSymbol(rot_d, rot_h, 9*sizeof(float_t), 0, cudaMemcpyHostToDevice); 
    cudaMemcpyToSymbol(transvec_d, transvec_h, 3*sizeof(float_t), 0, cudaMemcpyHostToDevice); 

    int num_threads = 256;
    int num_blocks =  nqz_ / num_threads + 1;
    dim3 ff_grid_size(num_blocks, 1, 1);
    dim3 ff_block_size(num_threads, 1, 1);
    std::cerr << "Q-Grid size = " << nqz_ << std::endl;

    // the kernel
    ff_prism6_kernel <<<num_blocks, num_threads >>> (nqy_, nqz_, 
            qx_, qy_, qz_, ff_, 
            n_x, x_d, distr_x_d, 
            n_y, y_d, distr_y_d);
    
    construct_output_ff(ff);

    cudaFree(distr_y_d);
    cudaFree(y_d);
    cudaFree(distr_x_d);
    cudaFree(x_d);
   
    return true;
  } // AnalyticFormFactorG::compute_prism6()

} // namespace hig

