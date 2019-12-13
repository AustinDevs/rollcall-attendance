#
# Copyright (C) 2014 - present Instructure, Inc.
#
# This file is part of Rollcall.
#
# Rollcall is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Rollcall is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

class InstructureRollcall.Models.CourseConfig extends Backbone.Model
  paramRoot: 'course_config'
  urlRoot: '/course_configs'

  defaults:
    course_id: null
    tardy_weight: null
    omit_from_final_grade: false

  tardyWeight: ->
    @get('tardy_weight') || 0.80

  tardyWeightPercentage: ->
    Math.round (@tardyWeight() * 100)

  setTardyWeight: (wholeNumber) ->
    @set 'tardy_weight', (parseInt(wholeNumber) / 100.0)

  omitFromFinalGrade: ->
    @get('omit_from_final_grade')

  setOmitFromFinalGrade: (boolValue) ->
    @set 'omit_from_final_grade', boolValue
