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

class GradeUpdater
  extend Resque::Plugins::Retry
  extend ResqueStats

  @queue = :grade_updates

  # directly enqueue job when lock occurred
  @retry_delay = 5

  # we don't need the limit because at some point the lock should be cleared
  # and because we are only catching LockTimeouts
  @retry_limit = 5

  # just catch lock timeouts
  @retry_exceptions = [Redlock::LockError]

  # expire key after `retry_delay` plus 1 hour
  @expire_retry_key_after = 3600

  def self.retry_identifier(params)
    params = params.with_indifferent_access
    params[:identifier]
  end
  def self.redis
    $REDIS
  end
  def self.perform(params)
    params = params.with_indifferent_access
    begin
      canvas = CanvasOauth::CanvasApiExtensions.build(
        params[:canvas_url],
        params[:user_id],
        params[:tool_consumer_instance_guid]
      )

      assignment = AttendanceAssignment.new(canvas, params[:course_id], params[:tool_launch_url], params[:tool_consumer_instance_guid])
      canvas_assignment = assignment.fetch_or_create

      lock_key = "grade_updater.guid_#{params[:tool_consumer_instance_guid]}" \
        ".assignment_id_#{canvas_assignment['id']}" \
        ".student_id_#{params[:student_id]}" \
        ".grade_#{assignment.get_student_grade(params[:student_id])}"

      lock_manager = Redlock::Client.new([redis.id])
      lock_manager.lock!(lock_key, 60) do |locked|
        # expiration and timeout are in seconds
          assignment.submit_grade(
          canvas_assignment['id'],
          params[:student_id])
      end

    rescue => e
      msg = "Exception submitting grade: #{e.to_s} with params:#{params.to_s}"
      Rails.logger.error msg
      raise
    end
  end
end
