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

#include <gtest/gtest.h>
#include "RunManagerTestFixture.hpp"
#include <runmanager/Test/ToolBin.hxx>
#include <resources.hxx>

#include "../JobFactory.hpp"
#include "../RunManager.hpp"
#include "../Workflow.hpp"

#include "../../../model/Model.hpp"

#include "../../../utilities/core/Application.hpp"
#include "../../../utilities/idf/IdfFile.hpp"
#include "../../../utilities/idf/IdfObject.hpp"
#include "../../../utilities/data/EndUses.hpp"
#include "../../../utilities/data/Attribute.hpp"
#include "../../../utilities/sql/SqlFile.hpp"

#include <boost/filesystem/path.hpp>

#include <QDir>
#include <QElapsedTimer>
#include <boost/filesystem.hpp>

using openstudio::Attribute;
using openstudio::IdfFile;
using openstudio::IdfObject;
using openstudio::IddObjectType;
using openstudio::SqlFile;

TEST_F(RunManagerTestFixture, ParallelEnergyPlusJobTest)
{
  openstudio::Application::instance().application(false);
  double originalSiteEnergy = 0;
  double parallelSiteEnergy = 0;

  QElapsedTimer et;
  et.start();

  {
    openstudio::path outdir = openstudio::toPath(QDir::tempPath()) / openstudio::toPath("ParallelEnergyPlusJobRunTest");
    boost::filesystem::create_directories(outdir);
    openstudio::path db = outdir / openstudio::toPath("ParallelEnergyPlusJobRunDB");
    openstudio::runmanager::RunManager kit(db, true);

    openstudio::path infile = outdir / openstudio::toPath("in.osm");
    openstudio::path weatherdir = resourcesPath() / openstudio::toPath("runmanager") / openstudio::toPath("USA_CO_Golden-NREL.724666_TMY3.epw");

    openstudio::model::Model m = openstudio::model::exampleModel();
    m.save(infile, true);


    openstudio::runmanager::Workflow workflow("modeltoidf->expandobjects->energyplus");

    workflow.setInputFiles(infile, weatherdir);

    // Build list of tools
    openstudio::runmanager::Tools tools 
      = openstudio::runmanager::ConfigOptions::makeTools(
          energyPlusExePath().parent_path(), 
          openstudio::path(), 
          openstudio::path(), 
          openstudio::path(),
          openstudio::path());
    workflow.add(tools);

    openstudio::runmanager::Job job = workflow.create(outdir);

    kit.enqueue(job, true);

    kit.waitForFinished();

    openstudio::path sqlpath = job.treeOutputFiles().getLastByExtension("sql").fullPath;

    openstudio::SqlFile sqlfile(sqlpath);

    ASSERT_TRUE(sqlfile.netSiteEnergy());
    originalSiteEnergy = *sqlfile.netSiteEnergy();
    ASSERT_TRUE(sqlfile.hoursSimulated());
    EXPECT_EQ(8760, *sqlfile.hoursSimulated());
  }

  qint64 originaltime = et.restart();

  {
    openstudio::path outdir = openstudio::toPath(QDir::tempPath()) / openstudio::toPath("ParallelEnergyPlusJobRunTest-part2");
    boost::filesystem::create_directories(outdir);
    openstudio::path db = outdir / openstudio::toPath("ParallelEnergyPlusJobRunDB");
    openstudio::runmanager::RunManager kit(db, true);

    openstudio::path infile = outdir / openstudio::toPath("in.osm");
    openstudio::path weatherdir = resourcesPath() / openstudio::toPath("runmanager") / openstudio::toPath("USA_CO_Golden-NREL.724666_TMY3.epw");

    openstudio::model::Model m = openstudio::model::exampleModel();
//    openstudio::runmanager::RunManager::simplifyModelForPerformance(m);
    m.save(infile, true);


    openstudio::runmanager::Workflow workflow("modeltoidf->expandobjects->energyplus");

    workflow.setInputFiles(infile, weatherdir);

    // Build list of tools
    openstudio::runmanager::Tools tools 
      = openstudio::runmanager::ConfigOptions::makeTools(
          energyPlusExePath().parent_path(), 
          openstudio::path(), 
          openstudio::path(), 
          openstudio::path(),
          openstudio::path());
    workflow.add(tools);

    int maxLocalJobs = kit.getConfigOptions().getMaxLocalJobs();
    workflow.parallelizeEnergyPlus(maxLocalJobs > 3 ? 3 : maxLocalJobs, 1);
    openstudio::runmanager::Job job = workflow.create(outdir);

    kit.enqueue(job, true);

    kit.waitForFinished();
    openstudio::path sqlpath = job.treeOutputFiles().getLastByExtension("sql").fullPath;

    openstudio::SqlFile sqlfile(sqlpath);

    ASSERT_TRUE(sqlfile.netSiteEnergy());
    parallelSiteEnergy = *sqlfile.netSiteEnergy();
    ASSERT_TRUE(sqlfile.hoursSimulated());
    EXPECT_EQ(8760, *sqlfile.hoursSimulated());
  }  

  qint64 paralleltime = et.restart();

  EXPECT_GT(paralleltime, 0);
  EXPECT_GT(originaltime, 0);

#if !(_DEBUG || (__GNUC__ && !NDEBUG))
  EXPECT_LT(paralleltime, originaltime);
#endif

  LOG(Debug, "Paralleltime " << paralleltime << " originaltime " << originaltime);

  EXPECT_NE(originalSiteEnergy, parallelSiteEnergy);
  EXPECT_LT(fabs(originalSiteEnergy - parallelSiteEnergy), .1);
}

