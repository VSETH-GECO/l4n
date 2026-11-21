require 'test_helper'

module Unit
  module Models
    class MenuLinkItemTest < ApplicationTest
      test 'absolute_external_link? is true for absolute http(s) links' do
        %w[https://example.com http://example.com/foo HTTPS://example.com //example.com/foo].each do |link|
          assert MenuLinkItem.new(external_link: link).absolute_external_link?, "expected #{link} to be absolute"
        end
      end

      test 'absolute_external_link? is false for relative or non-http links' do
        ['/news', 'pages/foo', '#anchor', '?a=b', 'mailto:info@example.com', 'not a valid url %%', nil, ''].each do |link|
          assert_not MenuLinkItem.new(external_link: link).absolute_external_link?, "expected #{link.inspect} not to be absolute"
        end
      end

      test 'absolute_external_link? is false for internal pages' do
        assert_not MenuLinkItem.new(static_page_name: 'news').absolute_external_link?
      end

      test 'href' do
        assert_equal 'https://example.com', MenuLinkItem.new(external_link: 'https://example.com').href
        assert_equal '/news', MenuLinkItem.new(external_link: '/news').href
        assert_equal '/news', MenuLinkItem.new(static_page_name: 'news').href
      end
    end
  end
end
