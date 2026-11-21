require 'test_helper'

module Unit
  module Models
    class StylingVariableTest < ApplicationTest
      setup do
        Rails.cache.delete('l4n/styling-variables')
      end

      test 'blank values are stored as nil' do
        variable = StylingVariable.create!(key: '--l4n-bg-color', light_mode_value: '  ', dark_mode_value: '#121214')

        assert_nil variable.light_mode_value
        assert_equal '#121214', variable.dark_mode_value
      end

      test 'generate_css skips blank values' do
        StylingVariable.create!(key: '--l4n-bg-color', light_mode_value: 'white', dark_mode_value: '#121214')
        # Simulate a value that was stored as empty string before blank values were normalized
        variable = StylingVariable.create!(key: '--l4n-card-bg-color', dark_mode_value: '#1c1c1f')
        StylingVariable.connection.execute("UPDATE styling_variables SET light_mode_value = '' WHERE id = #{variable.id}")
        assert_equal '', StylingVariable.where(id: variable.id).pick(Arel.sql('light_mode_value'))

        css = StylingVariable.generate_css

        assert_includes css, '--l4n-bg-color: white;'
        assert_includes css, '--l4n-card-bg-color: #1c1c1f;'
        assert_not_includes css, '--l4n-card-bg-color: ;'
      end
    end
  end
end
