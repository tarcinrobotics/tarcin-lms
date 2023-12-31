# frozen_string_literal: true

#
# Copyright (C) 2016 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

require_relative "course_copy_helper"

describe ContentMigration do
  context "course copy for external content" do
    include_context "course copy"

    let(:klass) do
      Class.new do
        class << self
          attr_reader :course, :migration, :imported_content

          def send_imported_content(course, migration, imported_content)
            @course = course
            @migration = migration
            @imported_content = imported_content
          end
        end
      end
    end

    before do
      allow(Canvas::Migration::ExternalContent::Migrator).to receive(:registered_services).and_return({ "test_service" => klass })
    end

    it "skips everything if #applies_to_course? returns false" do
      allow(klass).to receive(:applies_to_course?).and_return(false)
      expect(klass).not_to receive(:begin_export)
      expect(klass).not_to receive(:export_completed?)
      expect(klass).not_to receive(:retrieve_export)
      expect(klass).not_to receive(:send_imported_content)

      run_course_copy
    end

    it "sends the data from begin_export back later to retrieve_export" do
      expect(klass).to receive(:applies_to_course?).with(@copy_from).and_return(true)

      test_data = { sometestdata: "something" }
      expect(klass).to receive(:begin_export).with(@copy_from, {}).and_return(test_data)
      expect(klass).to receive(:export_completed?).with(test_data).and_return(true)
      expect(klass).to receive(:retrieve_export).with(test_data).and_return(nil)
      expect(klass).not_to receive(:send_imported_content)
      run_course_copy
    end

    it "translates ids for copied course content" do
      skip "Requires QtiMigrationTool" unless Qti.qti_enabled?

      assmt = @copy_from.assignments.create!
      topic = @copy_from.discussion_topics.create!(message: "hi", title: "discussion title")
      ann = @copy_from.announcements.create!(message: "goodbye")
      cm = @copy_from.context_modules.create!(name: "some module")
      item = cm.add_item(id: assmt.id, type: "assignment")
      att = Attachment.create!(filename: "first.txt", uploaded_data: StringIO.new("ohai"), folder: Folder.unfiled_folder(@copy_from), context: @copy_from)
      page = @copy_from.wiki_pages.create!(title: "wiki", body: "ohai")
      quiz = @copy_from.quizzes.create!

      data = {
        "$canvas_assignment_id" => assmt.id,
        "$canvas_discussion_topic_id" => topic.id,
        "$canvas_announcement_id" => ann.id,
        "$canvas_context_module_id" => cm.id,
        "$canvas_context_module_item_id" => item.id,
        "$canvas_file_id" => att.id, # $canvas_attachment_id works too
        "$canvas_page_id" => page.id,
        "$canvas_quiz_id" => quiz.id
      }

      allow(klass).to receive_messages(applies_to_course?: true,
                                       begin_export: true,
                                       export_completed?: true,
                                       retrieve_export: data)

      run_course_copy

      copied_assmt = @copy_to.assignments.where(migration_id: mig_id(assmt)).first
      copied_topic = @copy_to.discussion_topics.where(migration_id: mig_id(topic)).first
      copied_ann = @copy_to.announcements.where(migration_id: mig_id(ann)).first
      copied_cm = @copy_to.context_modules.where(migration_id: mig_id(cm)).first
      copied_item = @copy_to.context_module_tags.where(migration_id: mig_id(item)).first
      copied_att = @copy_to.attachments.where(migration_id: mig_id(att)).first
      copied_page = @copy_to.wiki_pages.where(migration_id: mig_id(page)).first
      copied_quiz = @copy_to.quizzes.where(migration_id: mig_id(quiz)).first

      expect(klass.course).to eq @copy_to

      expected_data = {
        "$canvas_assignment_id" => copied_assmt.id,
        "$canvas_discussion_topic_id" => copied_topic.id,
        "$canvas_announcement_id" => copied_ann.id,
        "$canvas_context_module_id" => copied_cm.id,
        "$canvas_context_module_item_id" => copied_item.id,
        "$canvas_file_id" => copied_att.id, # $canvas_attachment_id works too
        "$canvas_page_id" => copied_page.id,
        "$canvas_quiz_id" => copied_quiz.id
      }
      expect(klass.imported_content).to eq expected_data
    end

    it "specifies if the ids aren't able to be copied" do
      assmt = @copy_from.assignments.create!
      topic = @copy_from.discussion_topics.create!

      allow(klass).to receive_messages(applies_to_course?: true,
                                       begin_export: true,
                                       export_completed?: true,
                                       retrieve_export: { "$canvas_assignment_id" => assmt.id,
                                                          "$canvas_discussion_topic_id" => topic.id })

      @cm.copy_options = { "all_discussion_topics" => "1" }
      @cm.save!

      run_course_copy

      copied_topic = @copy_to.discussion_topics.where(migration_id: mig_id(topic)).first
      expected_data = {
        "$canvas_assignment_id" => "$OBJECT_NOT_FOUND",
        "$canvas_discussion_topic_id" => copied_topic.id
      }
      expect(klass.imported_content).to eq expected_data
    end

    it "sends a list of exported assets to the external service when selectively exporting" do
      assmt = @copy_from.assignments.create!
      @copy_from.assignments.create!
      graded_quiz = @copy_from.quizzes.create!
      graded_quiz.generate_quiz_data
      graded_quiz.workflow_state = "available"
      graded_quiz.save!

      cm = @copy_from.context_modules.create!(name: "some module")
      cm.add_item(id: assmt.id, type: "assignment")
      cm.add_item(id: graded_quiz.id, type: "quiz")

      allow(klass).to receive_messages(applies_to_course?: true,
                                       export_completed?: true,
                                       retrieve_export: {})

      @cm.copy_options = { context_modules: { mig_id(cm) => "1" } }
      @cm.save!

      expect(klass).to receive(:begin_export).with(@copy_from,
                                                   { selective: true, exported_assets: ["context_module_#{cm.id}", "assignment_#{assmt.id}", "quiz_#{graded_quiz.id}", "assignment_#{graded_quiz.assignment.id}"] })

      run_course_copy
    end

    it "only checks a few times for the export to finish before timing out" do
      allow(klass).to receive_messages(applies_to_course?: true, begin_export: true)
      expect(Canvas::Migration::ExternalContent::Migrator).to receive(:retry_delay).at_least(:once).and_return(0) # so we're not actually sleeping for 30s a pop
      expect(klass).to receive(:export_completed?).exactly(6).times.and_return(false) # retries 5 times

      expect(Canvas::Errors).to receive(:capture_exception).with(:external_content_migration,
                                                                 "External content migrations timed out for test_service",
                                                                 :warn)

      run_course_copy
    end
  end
end
