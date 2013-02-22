/***
  *  Project: HipGISAXS (High-Performance GISAXS)
  *
  *  File: ff_ana_sphere.cpp
  *  Created: Jul 12, 2012
  *  Modified: Thu 21 Feb 2013 04:39:07 PM PST
  *
  *  Author: Abhinav Sarje <asarje@lbl.gov>
  */

#include <boost/math/special_functions/fpclassify.hpp>

#include "woo/timer/woo_boostchronotimers.hpp"

#include "ff_ana.hpp"
#include "shape.hpp"
#include "enums.hpp"
#include "qgrid.hpp"
#include "utilities.hpp"
#include "numeric_utils.hpp"

namespace hig {

	/**
	 * sphere
	 */
	bool AnalyticFormFactor::compute_sphere(shape_param_list_t& params, std::vector<complex_t> &ff,
											vector3_t transvec) {
		std::vector<float_t> r, distr_r;
		for(shape_param_iterator_t i = params.begin(); i != params.end(); ++ i) {
			switch((*i).second.type()) {
				case param_edge:
				case param_xsize:
				case param_ysize:
				case param_height:
				case param_baseangle:
					std::cerr << "warning: ignoring unwanted parameters in sphere" << std::endl;
					break;
				case param_radius:
					param_distribution((*i).second, r, distr_r);
					break;
				default:
					std::cerr << "error: unknown or invalid parameter given for sphere" << std::endl;
					return false;
			} // switch
		} // for

		if(r.size() < 1) {
			std::cerr << "error: radius parameter required for sphere" << std::endl;
			return false;
		} // if

#ifdef TIME_DETAIL_2
		woo::BoostChronoTimer maintimer;
		maintimer.start();
#endif // TIME_DETAIL_2
#ifdef FF_ANA_GPU
		// on gpu
		std::cout << "-- Computing sphere FF on GPU ..." << std::endl;

		std::vector<float_t> transvec_v;
		transvec_v.push_back(transvec[0]);
		transvec_v.push_back(transvec[1]);
		transvec_v.push_back(transvec[2]);

		gff_.compute_sphere(r, distr_r, rot_, transvec_v, ff);
#else
		// on cpu
		std::cout << "-- Computing sphere FF on CPU ..." << std::endl;

		ff.clear(); ff.reserve(nqx_ * nqy_ * nqz_);
		for(unsigned int i = 0; i < nqx_ * nqy_ * nqz_; ++ i) ff.push_back(complex_t(0, 0));

		#pragma omp parallel for collapse(3)
		for(unsigned int z = 0; z < nqz_; ++ z) {
			for(unsigned int y = 0; y < nqy_; ++ y) {
				for(unsigned int x = 0; x < nqx_; ++ x) {
					complex_t mqx, mqy, mqz;
					compute_meshpoints(QGrid::instance().qx(x), QGrid::instance().qy(y),
										QGrid::instance().qz_extended(z), rot_, mqx, mqy, mqz);
					complex_t temp_q = sqrt(mqx * mqx + mqy * mqy + mqz * mqz);
					complex_t temp_ff(0.0, 0.0);
					for(unsigned int i_r = 0; i_r < r.size(); ++ i_r) {
						complex_t temp1 = temp_q * r[i_r];
						complex_t temp2 = sin(temp1) - temp1 * cos(temp1);
						complex_t temp3 = temp1 * temp1 * temp1;
						temp_ff += distr_r[i_r] * 4 * PI_ * pow(r[i_r], 3) * (temp2 / temp3) *
										exp(complex_t(0, 1) * mqz * r[i_r]);
					} // for r
					complex_t temp1 = mqx * transvec[0] + mqy * transvec[1] + mqz * transvec[2];
					complex_t temp2 = exp(complex_t(-temp1.imag(), temp1.real()));
					unsigned int curr_index = nqx_ * nqy_ * z + nqx_ * y + x;
					ff[curr_index] = temp_ff * temp2;
				} // for z
			} // for y
		} // for z
#endif // FF_ANA_GPU
#ifdef TIME_DETAIL_2
		maintimer.stop();
		std::cout << "**        Sphere FF compute time: " << maintimer.elapsed_msec() << " ms." << std::endl;
#endif // TIME_DETAIL_2
		
		return true;
	} // AnalyticFormFactor::compute_sphere()


} // namespace hig
