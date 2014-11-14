
module Iqeo
module Local
  class Runner
    def self.run args, out: $stdout, err: $stderr
      out.puts NetInfo.new.pretty_json
    end
  end
end
end

