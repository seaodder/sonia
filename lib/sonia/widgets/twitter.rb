require 'yajl'
require 'twitter/json_stream'

module Sonia
  module Widgets
    class Twitter < Sonia::Widget
      FRIENDS_URL           = "http://api.twitter.com/1/statuses/friends/%s.json"
      CREATE_FRIENDSHIP_URL = "http://api.twitter.com/1/friendships/create/%s.json?follow=true"
      USER_LOOKUP_URL       = "http://api.twitter.com/1/users/lookup.json?screen_name=%s"
      FRIENDS_TIMELINE_URL  = "http://api.twitter.com/1/statuses/friends_timeline.json?count=%s"

      def initialize(config)
        super(config)

        http1 = EventMachine::HttpRequest.new(friends_url).get(headers)
        http1.callback {
          friends_usernames = extract_friends(http1.response)

          new_friends_to_follow = follow_usernames - friends_usernames

          follow_new_users(new_friends_to_follow)

          lookup_user_ids_for(follow_usernames) {
            connect_to_stream
          }
        }
      end

      def initial_push
        http = EventMachine::HttpRequest.new(friends_timeline_url).get(headers)
        http.callback {
          Yajl::Parser.parse(http.response).reverse.each do |status|
            push format_status(status)
          end
        }
      end

      private
      def connect_to_stream
        @stream = ::Twitter::JSONStream.connect(
          :path    => "/1/statuses/filter.json",
          :content => "follow=#{@user_ids.join(',')}",
          :method  => "POST",
          :auth    => [config[:username], config[:password]].join(':')
        )

        @stream.each_item do |status|
          push format_status(Yajl::Parser.parse(status))
        end
      end

      def follow_new_users(users)
        users.each do |user|
          http = EventMachine::HttpRequest.new(create_friendship_url(user)).get(headers)
          http.callback {
            puts "Creating friendship with #{user}: #{http.response_header.status}"
          }
        end
      end

      def follow_usernames
        config[:follow].split(',') << "dougw"
      end

      def extract_friends(response)
        Yajl::Parser.parse(response).map { |user| user["screen_name"] }
      end

      def headers
        { :head => { 'Authorization' => [config[:username], config[:password]] } }
      end

      def create_friendship_url(user)
        CREATE_FRIENDSHIP_URL % user
      end

      def friends_timeline_url
        FRIENDS_TIMELINE_URL % config[:nitems]
      end

      def friends_url
        FRIENDS_URL % config[:username]
      end

      def user_lookup_url(users)
        USER_LOOKUP_URL % users.join(',')
      end

      def lookup_user_ids_for(usernames, &block)
        http = EventMachine::HttpRequest.new(user_lookup_url(follow_usernames)).get(headers)
        http.callback {
          @user_ids = Yajl::Parser.parse(http.response).map { |e| e["id"] }
          block.call
        }
      end

#       {
#         "in_reply_to_status_id":11025304529,
#         "text":"@weembow LOL 'I HATE EVERYTHING BUT ANGELA AND WEED' when the fuck did i do that hahahaha",
#         "place":null,
#         "in_reply_to_user_id":26580764,
#         "source":"web",
#         "coordinates":null,
#         "favorited":false,
#         "contributors":null,
#         "geo":null,
#         "user":{
#           "lang":"en",
#           "profile_background_tile":true,
#           "location":"minneapolis minnesota",
#           "following":null,
#           "profile_sidebar_border_color":"0d0d0d",
#           "profile_image_url":"http://a1.twimg.com/profile_images/734139740/26461_106304702728342_100000464390009_157589_7540067_n_normal.jpg",
#           "verified":false,
#           "geo_enabled":true,
#           "followers_count":56,
#           "friends_count":66,
#           "description":"SCUM FUCK EAT SHIT.",
#           "screen_name":"jewslaya",
#           "profile_background_color":"cadbba",
#           "url":"http://www.facebook.com/profile.php?ref=profile&id=100000464390009",
#           "favourites_count":0,
#           "profile_text_color":"262626",
#           "time_zone":"Central Time (US & Canada)",
#           "protected":false,
#           "statuses_count":3394,
#           "notifications":null,
#           "profile_link_color":"a61414",
#           "name":"delaney pain",
#           "profile_background_image_url":
#           "http://a1.twimg.com/profile_background_images/80655374/2370378327_10f7b17053_o.jpg",          "created_at":"Tue Jul 21 18:18:40 +0000 2009",
#           "id":58872581,
#           "contributors_enabled":false,
#           "utc_offset":-21600,
#           "profile_sidebar_fill_color":"f5e180"
#          },
#         "in_reply_to_screen_name":"weembow",
#         "id":11046874752,
#         "created_at":"Thu Mar 25 18:22:14 +0000 2010",
#         "truncated":false
#       }


      def format_status(status)
        {
          :text              => status['text'],
          :user              => status['user']['screen_name'],
          :profile_image_url => status['user']['profile_image_url']
        }
      end
    end
  end
end
