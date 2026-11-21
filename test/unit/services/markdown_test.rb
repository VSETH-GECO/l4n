require 'test_helper'

module Unit
  module Services
    class MarkdownTest < ApplicationTest
      def test_link_only_paragraphs_get_link_row_class
        html = ::Services::Markdown.render("[Info page](https://example.com)\n[Event page](https://example.org)")

        assert_includes html, '<p class="md-link-row">'
      end

      def test_paragraphs_with_text_and_links_stay_plain
        html = ::Services::Markdown.render('Visit the [contact page](https://example.com) for more.')

        assert_not_includes html, 'md-link-row'
      end

      def test_line_breaks_are_kept
        html = ::Services::Markdown.render("First line\nSecond line")

        assert_includes html, "<p>First line<br>\nSecond line</p>"
      end

      def test_text_between_two_links_is_not_a_link_row
        html = ::Services::Markdown.render('[a](https://a.example) and [b](https://b.example)')

        assert_not_includes html, 'md-link-row'
      end
    end
  end
end
