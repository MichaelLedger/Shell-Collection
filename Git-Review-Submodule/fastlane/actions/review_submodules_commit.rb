module Fastlane
  module Actions
    module SharedValues
      REVIEW_SUBMODULES_COMMIT_RESULT_VALUE = :REVIEW_SUBMODULES_COMMIT_RESULT_VALUE
    end

    class ReviewSubmodulesCommitAction < Action
      def self.run(params)
        # fastlane will take care of reading in the parameter and fetching the environment variable:
        # UI.message("Parameter API Token: #{params[:api_token]}")
        # UI.message("Review submodules commit-id")

        # sh "shellcommand ./path"
        script_path = File.expand_path("./fastlane/scripts/review_submodule_commit.py")
        UI.message("script_path #{script_path}")
        result = system "python3 #{script_path}"
        Actions.lane_context[SharedValues::REVIEW_SUBMODULES_COMMIT_RESULT_VALUE] = result
        UI.message("Result: #{Actions.lane_context[SharedValues::REVIEW_SUBMODULES_COMMIT_RESULT_VALUE]}")
        if result != true
            UI.user_error!("Whoops, something went wrong")
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        'Review submodules commit-id'
      end

      def self.details
        # Optional:
        # this is your chance to provide a more detailed description of this action
        # 'You can use this action to do cool things...'
      end

      def self.available_options
        # Define all options your action supports.

        # Below a few examples
#        [
#          FastlaneCore::ConfigItem.new(key: :api_token,
#                                       # The name of the environment variable
#                                       env_name: 'FL_REVIEW_SUBMODULES_COMMIT_API_TOKEN',
#                                       # a short description of this parameter
#                                       description: 'API Token for ReviewSubmodulesCommitAction',
#                                       verify_block: proc do |value|
#                                         unless value && !value.empty?
#                                           UI.user_error!("No API token for ReviewSubmodulesCommitAction given, pass using `api_token: 'token'`")
#                                         end
#                                         # UI.user_error!("Couldn't find file at path '#{value}'") unless File.exist?(value)
#                                       end),
#          FastlaneCore::ConfigItem.new(key: :development,
#                                       env_name: 'FL_REVIEW_SUBMODULES_COMMIT_DEVELOPMENT',
#                                       description: 'Create a development certificate instead of a distribution one',
#                                       # true: verifies the input is a string, false: every kind of value
#                                       is_string: false,
#                                       # the default value if the user didn't provide one
#                                       default_value: false)
#        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['REVIEW_SUBMODULES_COMMIT_RESULT_VALUE', 'review submodule commit result value (true/false)']
        ]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
        Actions.lane_context[SharedValues::REVIEW_SUBMODULES_COMMIT_RESULT_VALUE]
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ['gavin.xiang@planetart.cn']
      end

      def self.is_supported?(platform)
        # you can do things like
        #
        #  true
        #
        #  platform == :ios
        #
        #  [:ios, :mac].include?(platform)
        #
        true
      end
    end
  end
end
