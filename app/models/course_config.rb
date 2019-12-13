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

class CourseConfig < ApplicationRecord
  validates :course_id, :tool_consumer_instance_guid, presence: true
  validates :tardy_weight, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1, allow_nil: true }

  after_save :check_needs_regrade

  attr_reader :needs_regrade
  def check_needs_regrade
    @needs_regrade = (tardy_weight.present? && saved_change_to_tardy_weight?) || saved_change_to_omit_from_final_grade?
  end
end
