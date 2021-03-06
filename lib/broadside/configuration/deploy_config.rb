require 'dotenv'
require 'pathname'

module Broadside
  class Configuration
    class DeployConfig < ConfigStruct
      include Utils

      DEFAULT_PREDEPLOY_COMMANDS = [
        ['bundle', 'exec', 'rake', '--trace', 'db:migrate']
      ]

      attr_accessor(
        :type,
        :tag,
        :ssh,
        :rollback,
        :timeout,
        :target,
        :targets,
        :scale,
        :env_vars,
        :command,
        :instance,
        :lines,
        :predeploy_commands,
        :service_config,
        :task_definition_config
      )

      TARGET_ATTRIBUTE_VALIDATIONS = {
        scale: ->(target_attribute) { validate_types([Fixnum], target_attribute) },
        env_file: ->(target_attribute) { validate_types([String, Array], target_attribute) },
        command: ->(target_attribute) { validate_types([Array, NilClass], target_attribute) },
        predeploy_commands: ->(target_attribute) { validate_predeploy_commands(target_attribute) },
        service_config: ->(target_attribute) { validate_types([Hash, NilClass], target_attribute) },
        task_definition_config: ->(target_attribute) { validate_types([Hash, NilClass], target_attribute) }
      }

      def initialize
        @type = 'ecs'
        @ssh = nil
        @tag = nil
        @rollback = 1
        @timeout = 600
        @target = nil
        @targets = nil
        @scale = nil
        @env_vars = nil
        @command = nil
        @predeploy_commands = DEFAULT_PREDEPLOY_COMMANDS
        @instance = 0
        @service_config = nil
        @task_definition_config = nil
        @lines = 10
      end

      # Validates format of deploy targets
      # Checks existence of provided target
      def validate_targets!
        @targets.each do |target, configuration|
          invalid_messages = TARGET_ATTRIBUTE_VALIDATIONS.map do |var, validation|
            message = validation.call(configuration[var])
            message.nil? ? nil : "Deploy target '#{@target}' parameter '#{var}' is invalid: #{message}"
          end.compact

          unless invalid_messages.empty?
            raise ArgumentError, invalid_messages.join("\n")
          end
        end

        unless @targets.has_key?(@target)
          raise ArgumentError, "Could not find deploy target #{@target} in configuration !"
        end
      end

      # Loads deploy target data using provided target
      def load_target!
        validate_targets!
        load_env_vars!

        @scale ||= @targets[@target][:scale]
        @command = @targets[@target][:command]
        @predeploy_commands = @targets[@target][:predeploy_commands] if @targets[@target][:predeploy_commands]
        @service_config = @targets[@target][:service_config]
        @task_definition_config = @targets[@target][:task_definition_config]
      end

      def load_env_vars!
        @env_vars ||= {}

        [@targets[@target][:env_file]].flatten.each do |env_path|
          env_file = Pathname.new(env_path)

          unless env_file.absolute?
            dir = config.file.nil? ? Dir.pwd : Pathname.new(config.file).dirname
            env_file = env_file.expand_path(dir)
          end

          if env_file.exist?
            vars = Dotenv.load(env_file)
            @env_vars.merge!(vars)
          else
            raise ArgumentError, "Could not find file '#{env_file}' for loading environment variables !"
          end
        end

        # convert env vars to format ecs expects
        @env_vars = @env_vars.map { |k, v| { 'name' => k, 'value' => v } }
      end

      private

      def self.validate_types(types, target_attribute)
        if types.include?(target_attribute.class)
          nil
        else
          "'#{target_attribute}' must be of type [#{types.join('|')}], got '#{target_attribute.class}' !"
        end
      end

      def self.validate_predeploy_commands(commands)
        return nil if commands.nil?
        return 'predeploy_commands must be an array' unless commands.is_a?(Array)

        messages = commands.reject { |cmd| cmd.is_a?(Array) }.map do |command|
          "predeploy_command '#{command}' must be an array" unless command.is_a?(Array)
        end
        messages.empty? ? nil : messages.join(', ')
      end
    end
  end
end
