/**********************************************************************
 *  Copyright (c) 2008-2016, Alliance for Sustainable Energy.
 *  All rights reserved.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 **********************************************************************/

#ifndef UTILITIES_FILETYPES_WORKFLOWJSON_IMPL_HPP
#define UTILITIES_FILETYPES_WORKFLOWJSON_IMPL_HPP

#include "../UtilitiesAPI.hpp"

#include "WorkflowStep.hpp"

#include "../core/Logger.hpp"
#include "../core/Path.hpp"
#include "../data/Variant.hpp"
#include "../data/Attribute.hpp"

#include <jsoncpp/json.h>

namespace openstudio{
  
class DateTime;

namespace detail {

    class UTILITIES_API WorkflowJSON_Impl
    {
    public:

      WorkflowJSON_Impl();

      WorkflowJSON_Impl(const std::string& s);

      WorkflowJSON_Impl(const openstudio::path& p);

      WorkflowJSON clone() const;

      std::string string(bool includeHash = true) const;

      std::string hash() const;

      std::string computeHash() const;

      bool checkForUpdates();

      bool save() const;

      bool saveAs(const openstudio::path& p) const;

      void reset();

      void start();

      unsigned currentStepIndex() const;

      boost::optional<WorkflowStep> currentStep() const;

      bool incrementStep();

      boost::optional<std::string> completedStatus() const;

      void setCompletedStatus(const std::string& status);

      boost::optional<DateTime> createdAt() const;

      boost::optional<DateTime> startedAt() const;

      boost::optional<DateTime> updatedAt() const;

      boost::optional<DateTime> completedAt() const;

      boost::optional<openstudio::path> oswPath() const;

      bool setOswPath(const openstudio::path& path);

      openstudio::path oswDir() const;

      bool setOswDir(const openstudio::path& path);

      openstudio::path rootDir() const;
      openstudio::path absoluteRootDir() const;

      openstudio::path runDir() const;
      openstudio::path absoluteRunDir() const;

      openstudio::path outPath() const;
      openstudio::path absoluteOutPath() const;

      std::vector<openstudio::path> filePaths() const;
      std::vector<openstudio::path> absoluteFilePaths() const;

      boost::optional<openstudio::path> findFile(const openstudio::path& file) const;
      boost::optional<openstudio::path> findFile(const std::string& fileName) const;

      std::vector<openstudio::path> measurePaths() const;
      std::vector<openstudio::path> absoluteMeasurePaths() const;

      boost::optional<openstudio::path> findMeasure(const openstudio::path& measureDir) const;
      boost::optional<openstudio::path> findMeasure(const std::string& measureDirName) const;

      boost::optional<openstudio::path> seedFile() const;

      void resetSeedFile();

      bool setSeedFile(const openstudio::path& seedFile);

      boost::optional<openstudio::path> weatherFile() const;

      bool setWeatherFile(const openstudio::path& weatherFile);
    
      void resetWeatherFile();

      std::vector<WorkflowStep> workflowSteps() const;

      bool setWorkflowSteps(const std::vector<WorkflowStep>& steps);

    private:

      REGISTER_LOGGER("openstudio.WorkflowJSON");

      void onUpdate();

      void parseSteps();

      openstudio::path m_oswDir;
      openstudio::path m_oswFilename;
      Json::Value m_value;
      std::vector<WorkflowStep> m_steps;
    };

} // detail
} // openstudio

#endif //UTILITIES_FILETYPES_WORKFLOWJSON_IMPL_HPP