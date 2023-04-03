
module Iqeo
module Local
  class Runner
    def self.run args, out: $stdout, err: $stderr
      out.puts Network.new.pretty_json
    end
  end
end
end

