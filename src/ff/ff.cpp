/**
 *  Project: HipGISAXS (High-Performance GISAXS)
 *
 *  File: ff.cpp
 *  Created: Jul 17, 2012
 *  Modified: Wed 08 Oct 2014 12:17:43 PM PDT
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

#include <ff/ff.hpp>

namespace hig {

  void FormFactor::clear() {
    ff_.clear();
    analytic_ff_.clear();
    numeric_ff_.clear();
    is_analytic_ = false;
  } // FormFactor::clear()


  bool FormFactor::compute_form_factor(ShapeName shape, std::string shape_filename,
                    shape_param_list_t& params, float_t single_thickness,
                    vector3_t& transvec, float_t shp_tau, float_t shp_eta,
                    vector3_t& rot1, vector3_t& rot2, vector3_t& rot3
                    #ifdef USE_MPI
                      , woo::MultiNode& multi_node, std::string comm_key
                    #endif
                    ) {
    if(shape == shape_custom) {
      /* compute numerically */
      is_analytic_ = false;
      numeric_ff_.init(rot1, rot2, rot3, ff_);
      numeric_ff_.compute2 (shape_filename.c_str(), ff_, rot1, rot2, rot3
                #ifdef USE_MPI
                  , multi_node, comm_key
                #endif
                );
    } else {
      /* compute analytically */
      is_analytic_ = true;
      analytic_ff_.init(rot1, rot2, rot3, ff_);
      analytic_ff_.compute(shape, shp_tau, shp_eta, transvec,
                  ff_, params, single_thickness, rot1, rot2, rot3
                  #ifdef USE_MPI
                    , multi_node, comm_key
                  #endif
                  );
    } // if-else
    return true;
  } // FormFactor::compute_form_factor()


  /* temporaries */

  bool FormFactor::read_form_factor(const char* filename,
                    unsigned int nqx, unsigned int nqy, unsigned int nqz) {
    std::ifstream f(filename);
    ff_.clear();
    for(unsigned int z = 0; z < nqz; ++ z) {
      for(unsigned int y = 0; y < nqy; ++ y) {
        for(unsigned int x = 0; x < nqx; ++ x) {
          float_t tempr, tempi;
          f >> tempr; f >> tempi;
          ff_.push_back(complex_t(tempr, tempi));
        } // for
      } // for
    } // for
    f.close();

    return true;
  } // FormFactor::read_form_factor()


  void FormFactor::print_ff(unsigned int nqx, unsigned int nqy, unsigned int nqz) {
    for(unsigned int z = 0; z < nqz; ++ z) {
      for(unsigned int y = 0; y < nqy; ++ y) {
        for(unsigned int x = 0; x < nqx; ++ x) {
          unsigned int index = nqx * nqy * z + nqx * y + x;
          std::cout << ff_[index].real() << "," << ff_[index].imag() << "\t";
        } // for
        std::cout << std::endl;
      } // for
      std::cout << std::endl;
    } // for
  } // FormFactor::print_ff()


  void FormFactor::save (unsigned nrow, unsigned ncol, const char * filename) {
    std::ofstream out (filename);
    for (unsigned i = 0; i < nrow; i++){
      for (unsigned j = 0; j < ncol; j++ ) out << std::norm (ff_[i*ncol + j]) << " ";
      out << std::endl;
    }
    out.close();
  }

  void FormFactor::save_ff(unsigned int nqx, unsigned int nqy, unsigned int nqz,
                const char* filename) {
    std::ofstream f(filename);
    for(unsigned int z = 0; z < nqz; ++ z) {
      for(unsigned int y = 0; y < nqy; ++ y) {
        for(unsigned int x = 0; x < nqx; ++ x) {
          unsigned int index = nqx * nqy * z + nqx * y + x;
          //f << ff_[index].real() << "\t" << ff_[index].imag() << std::endl;
          f << std::norm(ff_[index]);
        } // for
        //f << std::endl;
        f << " ";
      } // for
      f << std::endl;
    } // for
    f.close();
  } // FormFactor::save_ff()

} // namespace hig
