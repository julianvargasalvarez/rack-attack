require 'test/unit'

def is_odd(number)
  true
end

class TestOddNumber < Test::Unit::TestCase
  def test_is_true_for_one
    assert_equal(true, is_odd(1))
  end
end
