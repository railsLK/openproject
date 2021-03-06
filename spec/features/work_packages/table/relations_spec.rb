require 'spec_helper'

describe 'Work Package table relations', js: true do
  let(:user) { FactoryGirl.create :admin }

  let(:type) { FactoryGirl.create(:type) }
  let(:type2) { FactoryGirl.create(:type) }
  let(:project) { FactoryGirl.create(:project, types: [type, type2]) }

  let(:wp_table) { Pages::WorkPackagesTable.new(project) }
  let(:relations) { ::Components::WorkPackages::Relations.new(relations) }
  let(:wp_timeline) { Pages::WorkPackagesTimeline.new(project) }

  let!(:wp_from) { FactoryGirl.create(:work_package, project: project, type: type2) }
  let!(:wp_to) { FactoryGirl.create(:work_package, project: project, type: type) }
  let!(:wp_to2) { FactoryGirl.create(:work_package, project: project, type: type) }

  let!(:relation) do
    FactoryGirl.create(:relation,
                       from: wp_from,
                       to: wp_to,
                       relation_type: Relation::TYPE_FOLLOWS)
  end
  let!(:relation2) do
    FactoryGirl.create(:relation,
                       from: wp_from,
                       to: wp_to2,
                       relation_type: Relation::TYPE_FOLLOWS)
  end

  before do
    login_as(user)
  end

  describe 'relations can be displayed and expanded' do
    include_context 'work package table helpers'

    let!(:query) do
      query              = FactoryGirl.build(:query, user: user, project: project)
      query.column_names = ['subject']
      query.filters.clear

      query.save!
      query
    end

    let(:type_column_id) { "relationsToType#{type.id}" }
    let(:type_column_follows) { 'relationsOfTypeFollows' }

    it do
      # Now visiting the query for category
      wp_table.visit_query(query)
      wp_table.expect_work_package_listed(wp_from, wp_to, wp_to2)

      add_wp_table_column "Relations to #{type.name}"
      add_wp_table_column "follows relations"

      wp_from_row = wp_table.row(wp_from)
      wp_from_to = wp_table.row(wp_to)

      # Expect count for wp_from in both columns to be one
      expect(wp_from_row).to have_selector(".#{type_column_id} .wp-table--relation-count", text: '2')
      expect(wp_from_row).to have_selector(".#{type_column_follows} .wp-table--relation-count", text: '2')

      # Expect count for wp_to in both columns to be not rendered
      expect(wp_from_to).to have_no_selector(".#{type_column_id} .wp-table--relation-count")
      expect(wp_from_to).to have_no_selector(".#{type_column_follows} .wp-table--relation-count")

      # Expand first column
      wp_from_row.find(".#{type_column_id} .wp-table--relation-indicator").click
      expect(page).to have_selector(".__relations-expanded-from-#{wp_from.id}", count: 2)
      related_row = page.first(".__relations-expanded-from-#{wp_from.id}")
      expect(related_row).to have_selector('td', text: "Follows#{wp_to.subject}")

      # Collapse
      wp_from_row.find(".#{type_column_id} .wp-table--relation-indicator").click
      expect(page).to have_no_selector(".__relations-expanded-from-#{wp_from.id}")

      # Expand second column
      wp_from_row.find(".#{type_column_follows} .wp-table--relation-indicator").click
      expect(page).to have_selector(".__relations-expanded-from-#{wp_from.id}", count: 2)
      related_row = page.first(".__relations-expanded-from-#{wp_from.id}")
      expect(related_row).to have_selector('td', text: "#{wp_to.type}#{wp_to.subject}")

      # Open Timeline
      # Should be initially closed
      wp_timeline.expect_timeline!(open: false)

      # Enable timeline
      wp_timeline.toggle_timeline
      wp_timeline.expect_timeline!(open: true)

      # 3 WPs + 2 expanded relations + inline create
      wp_timeline.expect_row_count(6)

      # Collapse
      wp_from_row.find(".#{type_column_follows} .wp-table--relation-indicator").click
      expect(page).to have_no_selector(".__relations-expanded-from-#{wp_from.id}")

      wp_timeline.expect_row_count(4)
    end
  end
end
