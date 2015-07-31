require 'mysql_users'

RSpec.describe(:user) do
  let(:database) do
    double()
  end
  let(:user) do
    MysqlUsers::User.new(database)
  end

  it 'should work' do
    user
  end
end
