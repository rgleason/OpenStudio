/***********************************************************************************************************************
 *  OpenStudio(R), Copyright (c) 2008-2016, Alliance for Sustainable Energy, LLC. All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
 *  following conditions are met:
 *
 *  (1) Redistributions of source code must retain the above copyright notice, this list of conditions and the following
 *  disclaimer.
 *
 *  (2) Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
 *  following disclaimer in the documentation and/or other materials provided with the distribution.
 *
 *  (3) Neither the name of the copyright holder nor the names of any contributors may be used to endorse or promote
 *  products derived from this software without specific prior written permission from the respective party.
 *
 *  (4) Other than as required in clauses (1) and (2), distributions in any form of modifications or other derivative
 *  works may not use the "OpenStudio" trademark, "OS", "os", or any other confusingly similar designation without
 *  specific prior written permission from Alliance for Sustainable Energy, LLC.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
 *  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 *  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR
 *  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 *  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 *  AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 **********************************************************************************************************************/

#ifndef ANALYSIS_SAMPLINGALGORITHMOPTIONS_IMPL_HPP
#define ANALYSIS_SAMPLINGALGORITHMOPTIONS_IMPL_HPP

#include "AnalysisAPI.hpp"
#include "DakotaAlgorithmOptions_Impl.hpp"

#include "SamplingAlgorithmOptions.hpp"

namespace openstudio {
namespace analysis {

class Problem;

namespace detail {

  /** SamplingAlgorithmOptions_Impl is a DakotaAlgorithmOptions_Impl that is the implementation class for SamplingAlgorithmOptions. */

  class ANALYSIS_API SamplingAlgorithmOptions_Impl : public DakotaAlgorithmOptions_Impl {
   public:
    /** @name Constructors and Destructors */
    //@{

    explicit SamplingAlgorithmOptions_Impl();

    /** Constructor provided for deserialization; not for general use. */
    SamplingAlgorithmOptions_Impl(const boost::optional<SamplingAlgorithmSampleType>& sampleType,
                                  const boost::optional<SamplingAlgorithmRNGType>& rngType,
                                  const std::vector<Attribute>& options);

    virtual ~SamplingAlgorithmOptions_Impl() {}

    virtual AlgorithmOptions clone() const override;

    //@}
    /** @name Getters */
    //@{

    /** Returns the sampling type if it exists, evaluates to false otherwise. DAKOTA will 
     *  automatically use latin hypercube sampling (LHS) if unspecified. */
    boost::optional<SamplingAlgorithmSampleType> sampleType() const;

    /** Returns the random number generator (RNG) type if it exists, evaluates to false 
     *  otherwise. DAKOTA defaults to Mersenne twister (mt19937). */
    boost::optional<SamplingAlgorithmRNGType> rngType() const;

    /** Returns the user-specified number of samples. */
    int samples() const;

    /** Returns whether or not the user-specified all_variables option is active, if set;
     *  the default value is false. */
    bool allVariables() const;

    /** Returns whether or not the user-specified variance_based_decomp option is active, if set;
     *  the default value is false. */
    bool varianceBasedDecomp() const;

    /** Returns whether or not the user-specified drop_tolerance option is active, if set;
     *  the default value is false. */
    bool dropTolerance() const;

    /** Returns the explict pseudo-random number generator seed if it exists, evaluates to false 
     *  otherwise. */
    boost::optional<int> seed() const;

    /** Returns whether or not the user-specified fixed_seed option is active, if set;
     *  the default value is false. */
    bool fixedSeed() const;

    //@}
    /** @name Setters */
    //@{
  
    void setSampleType(SamplingAlgorithmSampleType value);
  
    void clearSampleType();   
  
    void setRNGType(SamplingAlgorithmRNGType value);
  
    void clearRNGType();   

    /** The number of samples must be greater than zero. */
    bool setSamples(int value);

    /** Places the string "all_variables" in the .in file if true, otherwise nothing. */
    void setAllVariables(bool value);
  
    /** Places the string "variance_based_decomp" in the .in file if true, otherwise nothing.
     *  This is a computationally intensive option; it requires the evaluation of n*(m+2) samples,
     *  where n is the number of samples specified and m is the number of variables. */
    void setVarianceBasedDecomp(bool value);

    /** Places the string "drop_tolerance" in the .in file if true, otherwise nothing. */
    void setDropTolerance(bool value);

    /** Seed value must be greater than zero. */
    bool setSeed(int value);
  
    void clearSeed();  

    /** Places the string "fixed_seed" in the .in file if true, otherwise nothing. */
    void setFixedSeed(bool value);

    //@}
    /** @name Absent or Protected in Public Class */
    //@{

    virtual QVariant toVariant() const override;

    static SamplingAlgorithmOptions fromVariant(const QVariant& variant, const VersionString& version);

    //@}
   protected:
    boost::optional<SamplingAlgorithmSampleType> m_sampleType;
    boost::optional<SamplingAlgorithmRNGType> m_rngType;

   private:
    REGISTER_LOGGER("openstudio.analysis.SamplingAlgorithmOptions");
  };

} // detail

} // analysis
} // openstudio

#endif // ANALYSIS_SAMPLINGALGORITHMOPTIONS_IMPL_HPP
