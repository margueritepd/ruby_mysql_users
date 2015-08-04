require 'mysql_users'
require 'mysql2'

RSpec.describe(:user) do
  let(:database_client) do
    db_client = double(Mysql2::Client)
    allow(db_client).to receive(:query).and_return([])
    db_client
  end

  let(:user) do
    MysqlUsers::User.new(
      database_client,
      { username: 'marguerite', scope: '%' },
    )
  end

  let(:db_user_result) { [{'User' => 'marguerite', 'Scope' => '%'}] }
  let(:db_empty_result) { [] }
  let(:user_select_regex) { /SELECT User, Scope FROM mysql.user/ }

  context(:exists?) do

    it 'exists? should return true if that username+scope exists' do
      allow(database_client).to receive(:query).with(user_select_regex)
        .and_return(db_user_result)
      expect(user.exists?).to eq(true)
    end

    it 'exists? should return false if that username+scope doesn\'t exists' do
      allow(database_client).to receive(:query).with(user_select_regex)
        .and_return(db_empty_result)
      expect(user.exists?).to eq(false)
    end

    it 'should escape username before interpolating in sql string' do
      injection = "Robert'; DROP TABLE Students; --"
      user = MysqlUsers::User.new(
        database_client,
        { username: injection, scope: '%' },
      )

      expect(database_client).to_not receive(:query).with(/bert'/)
      expect(database_client).to receive(:query).with(/bert\\'/)

      user.exists?
    end

    it 'should escape scope before interpolating in sql string' do
      injection = "Robert'; DROP TABLE Students; --"
      user = MysqlUsers::User.new(
        database_client,
        { username: 'marguerite', scope: injection },
      )

      expect(database_client).to_not receive(:query).with(/bert'/)
      expect(database_client).to receive(:query).with(/bert\\'/)

      user.exists?
    end
  end

  context(:create_idempotently) do
    let(:create_user_regex) { /CREATE USER 'marguerite'@'%'/ }

    it 'should create the user if it doesn\'t exist' do
      allow(database_client).to receive(:query).with(user_select_regex)
        .and_return(db_empty_result)
      expect(database_client).to receive(:query).with(create_user_regex)

      user.create_idempotently
    end

    it 'should not create the user if it does exist' do
      allow(database_client).to receive(:query).with(user_select_regex)
        .and_return(db_user_result)
      expect(database_client).to_not receive(:query).with(create_user_regex)

      user.create_idempotently
    end
  end

end
