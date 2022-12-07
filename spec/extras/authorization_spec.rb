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

require 'spec_helper'

describe Authorization do
  let(:object) { Object.new }
  before :each do
    object.extend(Authorization)
    object.extend(CanvasCache)
    object.instance_eval do
      def launch_url
        'http://localhost:3001'
      end

      def canvas
        @canvas ||= OpenStruct.new
      end

      def session
        @session ||= {}
      end

      def tool_consumer_instance_guid
        'abc123'
      end
    end
  end

  describe "authorize_resource" do
    subject { object.authorize_resource(:section, 1, nil) }

    context "when already authorized" do
      before { allow(object).to receive(:authorized?).and_return(true) }
      it { is_expected.to be_truthy }
    end

    context "when Canvas authorization succeeds" do
      before do
        allow(object).to receive(:authorized?).and_return(false)
        allow(object).to receive(:canvas_authorized?).and_return(true)
      end

      it "authorizes the resource" do
        expect(object).to receive(:authorize).with(:section, 1)
        subject
      end
    end

    context "when Canvas authorization fails" do
      before do
        allow(object).to receive(:authorized?).and_return(false)
        allow(object).to receive(:canvas_authorized?).and_raise(CanvasOauth::CanvasApi::Unauthorized)
      end

      it "raises an error" do
        expect { subject }.to raise_error CanvasOauth::CanvasApi::Unauthorized
      end
    end
  end

  describe "authorize" do
    before do
      allow(object).to receive(:session).and_return({})
      object.authorize(:section, 1)
    end

    it "caches the ID in the session" do
      expect(object.session[:authorization][:section]).to eq([1])
    end

    it "makes authorized? return true" do
      expect(object.authorized?(:section, 1)).to be_truthy
    end

    it "does not make authorized? return true for other resources" do
      expect(object.authorized?(:section, 2)).to be_falsey
      expect(object.authorized?(:course, 1)).to be_falsey
    end
  end


  def load_and_authorize_course(course_id)
    if authorize_resource :course, course_id, lambda { canvas.get_course(course_id) }
      Course.new(cached_course(course_id))
    end
  end

  describe "load_and_authorize_course" do
    subject { object.load_and_authorize_course(1) }

    context "when authorized" do
      before do
        allow(object).to receive(:authorize_resource).with(:course, 1, anything()).and_return(true)
        allow(object).to receive(:cached_course).and_return(id: 1)
      end

      it { is_expected.to be_a Course }
      its(:id) { should == 1 }
    end

    context "when not authorized" do
      before { allow(object).to receive(:authorize_resource).and_raise(CanvasOauth::CanvasApi::Unauthorized) }

      specify { expect { subject }.to raise_error(CanvasOauth::CanvasApi::Unauthorized) }
    end
  end

  describe "load_and_authorize_sections" do
    subject { object.load_and_authorize_sections(1) }

    context "when authorized" do
      before do
        allow(object).to receive(:load_and_authorize_course).with(1).and_return(true)
        allow(object).to receive(:cached_sections).and_return([{id: 1}, {id: 2}])
      end

      it { is_expected.to be_an Array }
      its(:size) { should == 2 }
      its(:first) { should be_a Section }
    end

    context "when not authorized" do
      before { allow(object).to receive(:authorize_resource).and_raise(CanvasOauth::CanvasApi::Unauthorized) }

      specify { expect { subject }.to raise_error(CanvasOauth::CanvasApi::Unauthorized) }
    end
  end

  describe "load_and_authorize_section" do
    subject { object.load_and_authorize_section(1) }

    context "when authorized" do
      before do
        allow(object).to receive(:authorize_resource).with(:section, 1, anything()).and_return(true)
        allow(object).to receive(:cached_section).and_return(id: 1)
      end

      it { is_expected.to be_a Section }
      its(:id) { should == 1 }
    end

    context "when not authorized" do
      before { allow(object).to receive(:authorize_resource).and_raise(CanvasOauth::CanvasApi::Unauthorized) }

      specify { expect { subject }.to raise_error(CanvasOauth::CanvasApi::Unauthorized) }
    end

  end

  describe "load_and_authorize_account" do
    subject { object.load_and_authorize_account(1, 'tci_guid') }

    context "when authorized" do
      before do
        allow(object).to receive(:authorize_resource).with(:account, 1, anything()).and_return(true)
        allow(object).to receive(:cached_account).and_return(id: 1)
      end

      it { is_expected.to be_an CachedAccount }
      its(:account_id) { should == 1 }
    end

    context "when not authorized" do
      before { allow(object).to receive(:authorize_resource).and_raise(CanvasOauth::CanvasApi::Unauthorized) }

      specify { expect { subject }.to raise_error(CanvasOauth::CanvasApi::Unauthorized) }
    end
  end

  describe "load_and_authorize_full_section" do
    subject { object.load_and_authorize_full_section(1) }
    let(:full_section) { Section.new(id: 1, course_id: 2, students: []) }

    context "when authorized" do
      before do
        allow(object).to receive(:load_and_authorize_section).with(1).and_return(Section.new(id: 1, course_id: 2))
        allow(object).to receive(:load_and_authorize_sections).with(2).and_return([full_section, Section.new(id: 2)])
      end

      it { is_expected.to eq(full_section) }
    end

    context "when not authorized" do
      before { allow(object).to receive(:load_and_authorize_section).and_raise(CanvasOauth::CanvasApi::Unauthorized) }

      specify { expect { subject }.to raise_error(CanvasOauth::CanvasApi::Unauthorized) }
    end
  end

  describe 'load_and_authorize_student' do
    subject { object.load_and_authorize_student(1, 2) }

    context 'when authorized' do
      it "uses a user's ability to view a given submission as authorization" do
        response_double = double('response')
        expect_any_instance_of(AttendanceAssignment).to receive(:fetch).and_return({ 'id' => 3 })
        expect(object.canvas).to receive(:get_submission).with(1, 3, 2).and_return(response_double)
        expect(response_double).to receive(:success?).and_return(true)
        subject
        expect(object.session).to eql(authorization: { student: [2] })
      end
    end

    context 'when not authorized' do
      before { allow(object).to receive(:load_and_authorize_student).with(1, 2).and_raise(CanvasOauth::CanvasApi::Unauthorized) }

      it { expect { subject }.to raise_error(CanvasOauth::CanvasApi::Unauthorized) }
    end
  end
end
