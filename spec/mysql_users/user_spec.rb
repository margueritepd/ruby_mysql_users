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

  def with_no_user_in_db
    allow(database_client).to receive(:query).with(user_select_regex)
      .and_return(db_empty_result)
  end

  def with_user_in_db
    allow(database_client).to receive(:query).with(user_select_regex)
      .and_return(db_user_result)
  end

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
      with_user_in_db
      expect(user.exists?).to eq(true)
    end

    it 'exists? should return false if that username+scope doesn\'t exists' do
      with_no_user_in_db
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
      with_no_user_in_db
      expect(database_client).to receive(:query).with(create_user_regex)

      user.create_idempotently
    end

    it 'should not create the user if it does exist' do
      with_user_in_db
      expect(database_client).to_not receive(:query).with(create_user_regex)

      user.create_idempotently
    end

    it 'should create the user with password if password given' do
      with_no_user_in_db
      user = MysqlUsers::User.new(
        database_client,
        { username: 'u', scope: '%', password: 'p' },
      )

      expect(database_client).to receive(:query).with(
        /^CREATE USER 'u'@'%' IDENTIFIED BY 'p'$/
      )

      user.create_idempotently
    end

    it 'should escape interpolated password when creating' do
      with_no_user_in_db
      user = MysqlUsers::User.new(
        database_client,
        { username: 'u', scope: '%', password: bobby_tables },
      )
      expect(database_client).to_not receive(:query).with(/bert'/)
      expect(database_client).to receive(:query).with(/^CREATE.*bert\\'/)

      user.create_idempotently
    end
  end

  context(:drop) do
    it 'should remove user from database' do
      expect(database_client).to receive(:query).with(
        %q{DROP USER 'marguerite'@'%'}
      )
      user.drop
    end
  end

  context(:grant) do
    let(:grant_options) do
      {
        database: 'db',
        table: 'tbl',
        grants: [
          :select
        ]
      }
    end

    it 'should grant to * if no database provided' do
      grant_options.delete(:database)
      expect(database_client).to receive(:query).with('*.`tbl`')
      user.grant(grant_options)
    end

    it 'should grant to * if no table provided' do
      grant_options.delete(:table)
      expect(database_client).to receive(:query).with('`db`.*')
      user.grant(grant_options)
    end

    it 'should surround table and db name in backticks' do
      expect(database_client).to receive(:query).with('`db`.`tbl`')
      user.grant(grant_options)
    end

    it 'should error if provided table name contains backticks' do
      expect(database_client).to_not receive(:query).with(/stompy`/)
      expect {
        user.grant(grant_options.merge({table: 'stompy`'}))
      }.to raise_error(/refusing to give grants/)
    end

    it 'should error if provided database name contains `' do
      expect(database_client).to_not receive(:query).with(/stompy`/)
      expect {
        user.grant(grant_options.merge({database: 'stompy`'}))
      }.to raise_error(/refusing to give grants/)
    end

  end
end
