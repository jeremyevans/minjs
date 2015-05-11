require 'spec_helper'

describe 'Statement' do
  describe 'Var' do
    it 'is var statement' do
      js = test_parse <<-EOS
var a;
var b=1;
var c,d=2,e;
console.log(a,b,c,d,e)
EOS
      expect(js).to eq "var a;var b=1;var c,d=2,e;console.log(a,b,c,d,e);"
    end
  end
end
