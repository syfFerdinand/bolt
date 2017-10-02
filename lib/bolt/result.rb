require 'json'

module Bolt
  class Result
    def value
      nil
    end

    def error
      nil
    end

    def to_h
      { 'value' => value }
    end
  end

  class CommandResult < Result
    def initialize(stdout, stderr, exit_code)
      @stdout = stdout
      @stderr = stderr
      @exit_code = exit_code
    end

    def value
      {
        'stdout' => @stdout,
        'stderr' => @stderr,
        'exit_code' => @exit_code
      }
    end

    def success?
      @exit_code.zero?
    end
  end

  class TaskResult < CommandResult
    attr_reader :error

    def initialize(stdout, stderr, exit_code)
      super(stdout, stderr, exit_code)
      @object = output_to_json_hash(stdout)
      @error = @object.delete('_error') if @object
    end

    def value
      @object || { '_output' => @stdout }
    end

    def to_h
      hash = super
      hash['_error'] = error if error
      hash
    end

    private

    def output_to_json_hash(output)
      obj = JSON.parse(output)
      if obj.is_a? Hash
        obj
      end
    rescue JSON::ParserError
      nil
    end
  end

  class TaskSuccess < TaskResult
    def success?
      true
    end
  end

  class TaskFailure < TaskResult
    def initialize(stdout, stderr, exit_code)
      super(stdout, stderr, exit_code)
      @error ||= generate_error
    end

    def success?
      false
    end

    private

    def generate_error
      {
        'kind' => 'puppetlabs.tasks/task-error',
        'issue_code' => 'TASK_ERROR',
        'msg' => "The task failed with exit code #{@exit_code}",
        'details' => { 'exit_code' => @exit_code }
      }
    end
  end

  class ExceptionResult < Result
    def initialize(exception)
      @exception = exception
    end

    def error
      {
        'kind' => 'puppetlabs.tasks/exception-error',
        'issue_code' => 'EXCEPTION',
        'msg' => @exception.message,
        'details' => { 'stack_trace' => @exception.backtrace.join('\n') }
      }
    end

    def to_h
      { '_error' => error }
    end
  end
end
