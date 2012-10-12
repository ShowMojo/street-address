require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Run tests"
task :default => :test

task :filter_file do
  $:.unshift File.join(File.dirname(__FILE__), "lib")
  require 'benchmark'
  require 'street_address'
  
  unless ARGV.length == 4
    puts "Expected format: `rake filter_file addresses_in.txt good_addresses_out.txt bad_addresses_out.txt`"
  else
    input = File.readlines(ARGV[1])
    good_out, bad_out = ARGV[2..3].map{|p| File.open p, "w" }
    count, good, bad, start = 0, 0, 0, Time.now
    lines = input.count
    
    puts # progress will go on this line

    bm = Benchmark.measure do
      input.each do |address_input|
        address_input = "#{$1}\n" if address_input =~ /^"(.*)"$/
        address_obj = StreetAddress::US.parse(address_input)
        if address_obj
          good_out.write address_input
          good += 1
        else
          bad_out.write address_input
          bad += 1
        end
        count += 1
        print "\r%6.2f %" % ((count/lines.to_f) * 100) if count % 100 == 0
      end
      print "\r100.00 %\n\n"
    end
    
    good_out.close
    bad_out.close

    elapsed = Time.now - start
    puts "Processed #{count} addresses in #{elapsed.round(2)}s (#{(count/elapsed).round(2)} addresses/second)"
    puts "  Good Addresses: " + sprintf("%#{lines.to_s.length}d", good)
    puts "  Bad  Addresses: " + sprintf("%#{lines.to_s.length}d", bad)
    puts
    puts "      user     system      total        real"
    puts bm
  end
end
