require 'mysql_users'
require 'mysql2'

RSpec.describe(:user) do
  let(:database_client) do
    double(Mysql2::Client)
  end

  let(:user) do
    MysqlUsers::User.new(
      database_client,
      {
        username: 'marguerite',
        scope: '%',
      },
    )
  end

  it 'exists? should return true if that username+scope exists' do
    allow(database_client).to receive(:query).with(
      /SELECT User, Scope FROM mysql.user/
    ).and_return(
      [{'User' => 'marguerite', 'Scope' => '%'}]
    )
    expect(user.exists?).to eq(true)
  end

  it 'exists? should return false if that username+scope doesn\'t exists' do
    allow(database_client).to receive(:query).with(
      /SELECT User, Scope FROM mysql.user/
    ).and_return([])
    expect(user.exists?).to eq(false)
  end
end
