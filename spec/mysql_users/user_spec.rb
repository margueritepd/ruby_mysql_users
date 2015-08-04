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
  let(:bobby_tables) { "Robert'; DROP TABLE Students; --" }

  context(:new) do
    it 'errors if username is missing' do
      expect {
        MysqlUsers::User.new(database_client, { scope: '%' })
      }.to raise_exception(KeyError)
    end

    it 'errors if scope is missing' do
      expect {
        MysqlUsers::User.new(database_client, { username: 'marg' })
      }.to raise_exception(KeyError)
    end
  end

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
      user = MysqlUsers::User.new(
        database_client,
        { username: bobby_tables, scope: '%' },
      )

      expect(database_client).to_not receive(:query).with(/bert'/)
      expect(database_client).to receive(:query).with(/bert\\'/)

      user.exists?
    end

    it 'should escape scope before interpolating in sql string' do
      user = MysqlUsers::User.new(
        database_client,
        { username: 'marguerite', scope: bobby_tables },
      )

      expect(database_client).to_not receive(:query).with(/bert'/)
      expect(database_client).to receive(:query).with(/bert\\'/)

      user.exists?
    end
  end

  context(:create_idempotently) do
    let(:create_user_regex) { /^CREATE USER 'marguerite'@'%'$/ }

    it 'should create the user without password if no password given' do
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

    it 'should create the user with password if password given' do
      user = MysqlUsers::User.new(
        database_client,
        { username: 'u', scope: '%', password: 'p' },
      )

      allow(database_client).to receive(:query).with(user_select_regex)
        .and_return(db_empty_result)
      expect(database_client).to receive(:query).with(
        /^CREATE USER 'u'@'%' IDENTIFIED BY 'p'$/
      )

      user.create_idempotently
    end

    it 'should escape interpolated password when creating' do
      user = MysqlUsers::User.new(
        database_client,
        { username: 'u', scope: '%', password: bobby_tables },
      )
      allow(database_client).to receive(:query).with(user_select_regex)
        .and_return(db_empty_result)
      expect(database_client).to_not receive(:query).with(/bert'/)
      expect(database_client).to receive(:query).with(/^CREATE.*bert\\'/)

      user.create_idempotently
    end
  end

end
