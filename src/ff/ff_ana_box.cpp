/**
 *  Project: HipGISAXS (High-Performance GISAXS)
 *
 *  File: ff_ana_box.cpp
 *  Created: Jul 12, 2012
 *  Modified: Wed 22 Oct 2014 05:29:47 PM PDT
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

#include <boost/math/special_functions/fpclassify.hpp>

#include <woo/timer/woo_boostchronotimers.hpp>

#include <ff/ff_ana.hpp>
#include <common/enums.hpp>
#include <model/shape.hpp>
#include <model/qgrid.hpp>
#include <utils/utilities.hpp>
#include <numerics/numeric_utils.hpp>

namespace hig {

  /**
   * box
   */
  bool AnalyticFormFactor::compute_box(unsigned int nqx, unsigned int nqy, unsigned int nqz,
                    std::vector<complex_t>& ff,
                    ShapeName shape, shape_param_list_t& params,
                    float_t tau, float_t eta, vector3_t &transvec,
                    vector3_t &rot1, vector3_t &rot2, vector3_t &rot3) {
    std::vector <float_t> x, distr_x;  // for x dimension: param_xsize  param_edge
    std::vector <float_t> y, distr_y;  // for y dimension: param_ysize  param_edge
    std::vector <float_t> z, distr_z;  // for z dimension: param_height param_edge
    for(shape_param_iterator_t i = params.begin(); i != params.end(); ++ i) {
      if(!(*i).second.isvalid()) {
        std::cerr << "warning: invalid shape parameter found" << std::endl;
        continue;
      } // if
      switch((*i).second.type()) {
        case param_edge:
          param_distribution((*i).second, x, distr_x);  // x == RR, distr_x == RRD
          param_distribution((*i).second, y, distr_y);
          param_distribution((*i).second, z, distr_z);
          break;
        case param_xsize:
          param_distribution((*i).second, x, distr_x);
          break;
        case param_ysize:
          param_distribution((*i).second, y, distr_y);
          break;
        case param_height:
          param_distribution((*i).second, z, distr_z);
          break;
        case param_radius:
        case param_baseangle:
          std::cerr << "warning: ignoring unwanted values for shape type 'box'" << std::endl;
          break;
        default:
          std::cerr << "warning: unknown parameters for shape type 'box'. ignoring"
                << std::endl;
      } // switch
    } // for

    // check if x y z etc are set or not
    if(x.size() < 1 || y.size() < 1 || z.size() < 1) {
      std::cerr << "error: invalid or not enough box parameters given" << std::endl;
      return false;
    } // if

    #ifdef TIME_DETAIL_2
      woo::BoostChronoTimer maintimer;
      maintimer.start();
    #endif // TIME_DETAIL_2
    #ifdef FF_ANA_GPU
      // on gpu
      #ifdef FF_VERBOSE
        std::cout << "-- Computing box FF on GPU ..." << std::endl;
      #endif

      std::vector<float_t> transvec_v;
      transvec_v.push_back(transvec[0]);
      transvec_v.push_back(transvec[1]);
      transvec_v.push_back(transvec[2]);
      gff_.compute_box(tau, eta, x, distr_x, y, distr_y, z, distr_z, rot_, transvec_v, ff);
    #else
      // on cpu
      std::cout << "-- Computing box FF on CPU ..." << std::endl;
      // initialize ff
      ff.clear();  ff.reserve(nqz * nqy * nqx);
      for(unsigned int i = 0; i < nqz * nqy * nqx; ++ i) ff.push_back(complex_t(0, 0));

      #pragma omp parallel for collapse(3)
      for(unsigned int j_z = 0; j_z < nqz; ++ j_z) {
        for(unsigned int j_y = 0; j_y < nqy; ++ j_y) {
          for(unsigned int j_x = 0; j_x < nqx; ++ j_x) {
            complex_t mqx, mqy, mqz;
            compute_meshpoints(QGrid::instance().qx(j_x), QGrid::instance().qy(j_y),
                      QGrid::instance().qz_extended(j_z), rot_, mqx, mqy, mqz);
            complex_t temp1 = sin(eta) * mqx;
            complex_t temp2 = cos(eta) * mqy;
            complex_t temp3 = temp1 + temp2;
            complex_t temp_qm = tan(tau) * temp3;
            complex_t temp_ff(0.0, 0.0);
            for(unsigned int i_z = 0; i_z < z.size(); ++ i_z) {
              for(unsigned int i_y = 0; i_y < y.size(); ++ i_y) {
                for(unsigned int i_x = 0; i_x < x.size(); ++ i_x) {
                  complex_t temp1 = mqz + temp_qm;
                  complex_t temp2 = mqy * y[i_y];
                  complex_t temp3 = mqx * x[i_x];
                  complex_t temp4 = fq_inv(temp1, z[i_z]);
                  complex_t temp5 = sinc(temp2);
                  complex_t temp6 = sinc(temp3);
                  complex_t temp7 = temp6 * temp5;
                  complex_t temp8 = temp7 * temp4;
                  complex_t temp9 = 4 * distr_x[i_x] * distr_y[i_y] * distr_z[i_z] *
                            x[i_x] * y[i_y];
                  complex_t temp10 = temp9 * temp8;
                  temp_ff += temp10;
                  /*if(!(boost::math::isfinite(temp10.real()) &&
                      boost::math::isfinite(temp10.imag()))) {
                    std::cerr << "+++++++++++++++ here it is +++++++ " << j_x << ", "
                          << j_y << ", " << j_z << std::endl;
                    exit(1);
                  } // if*/
                } // for i_x
              } // for i_y
            } // for i_z
            complex_t temp7 = (mqx * transvec[0] + mqy * transvec[1] + mqz * transvec[2]);
            /*if(!(boost::math::isfinite(temp7.real()) && boost::math::isfinite(temp7.imag()))) {
              std::cerr << "---------------- here it is ------ " << j_x << ", "
                    << j_y << ", " << j_z << std::endl;
              exit(1);
            } // if*/
            unsigned int curr_index = nqx * nqy * j_z + nqx * j_y + j_x;
            ff[curr_index] = temp_ff * exp(complex_t(-temp7.imag(), temp7.real()));
            /*if(!(boost::math::isfinite(ff[curr_index].real()) &&
                boost::math::isfinite(ff[curr_index].imag()))) {
              std::cerr << "******************* here it is ********* " << j_x << ", "
                    << j_y << ", " << j_z << std::endl;
              exit(1);
            } // if*/
          } // for x
        } // for y
      } // for z
    #endif // FF_ANA_GPU
    #ifdef TIME_DETAIL_2
      maintimer.stop();
      std::cout << "**           Box FF compute time: " << maintimer.elapsed_msec() << " ms." << std::endl;
    #endif // TIME_DETAIL_2

    return true;
  } // AnalyticFormFactor::compute_box()

} // namespace hig
