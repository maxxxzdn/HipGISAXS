/**
 * $Id: reduction.hpp 38 2012-08-09 23:01:20Z asarje $
 *
 * Project: HipGISAXS (High-Performance GISAXS)
 */

#ifndef _MISC_H_
#define _MISC_H_

namespace hig {

	#ifndef GPUR
	void reduction_kernel(unsigned int, unsigned int, unsigned int,
							unsigned int, unsigned long int,
							unsigned int, unsigned int, unsigned int,
							unsigned int,
							unsigned int, unsigned int, unsigned int,
							unsigned int, unsigned int, unsigned int, unsigned int,
							cuComplex*, cuComplex*);

	void reduction_kernel(unsigned int, unsigned int, unsigned int,
							unsigned int, unsigned long int,
							unsigned int, unsigned int, unsigned int,
							unsigned int,
							unsigned int, unsigned int, unsigned int,
							unsigned int, unsigned int, unsigned int, unsigned int,
							cuDoubleComplex*, cuDoubleComplex*);
	#else
	__global__ void reduction_kernel(cuComplex*,
										unsigned int, unsigned int, unsigned int,
										unsigned int,
										unsigned int, unsigned int, unsigned int, unsigned int,
										cuComplex*);

	__global__ void reduction_kernel(cuDoubleComplex*,
										unsigned int, unsigned int, unsigned int,
										unsigned int,
										unsigned int, unsigned int, unsigned int, unsigned int,
										cuDoubleComplex*);
	#endif // GPUR

} // namespace hig

#endif // _MISC_H_
