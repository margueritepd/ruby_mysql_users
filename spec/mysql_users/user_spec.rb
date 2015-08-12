require 'mysql_users'

RSpec.describe(:user) do
  let(:database_client) do
    db_client = double()
    allow(db_client).to receive(:query).and_return([])
    allow(db_client).to receive(:escape) do |string|
      string.gsub('\\', '\\').gsub("'", { "'" => "\\'" })
    end
    db_client
  end

  let(:user) do
    MysqlUsers::User.new(
      database_client,
      { username: 'marguerite', host: '%' },
    )
  end

  let(:db_user_result) { [{'User' => 'marguerite', 'Host' => '%'}] }
  let(:db_empty_result) { [] }
  let(:user_select_regex) { /SELECT User, Host FROM mysql.user/ }
  let(:bobby_tables) { "Robert'; DROP TABLE Students; --" }

  def with_no_user_in_db
    allow(database_client).to receive(:query).with(user_select_regex)
      .and_return(db_empty_result)
  end

  def with_user_in_db
    allow(database_client).to receive(:query).with(user_select_regex)
      .and_return(db_user_result)
  end

  context('.new') do
    it 'errors if username is missing' do
      expect {
        MysqlUsers::User.new(database_client, { host: '%' })
      }.to raise_exception(KeyError)
    end

    it 'errors if host is missing' do
      expect {
        MysqlUsers::User.new(database_client, { username: 'marg' })
      }.to raise_exception(KeyError)
    end
  end

  context('#exists?') do

    it 'exists? should return true if that username+host exists' do
      with_user_in_db
      expect(user.exists?).to eq(true)
    end

    it 'exists? should return false if that username+host doesn\'t exists' do
      with_no_user_in_db
      expect(user.exists?).to eq(false)
    end

    it 'should escape username before interpolating in sql string' do
      user = MysqlUsers::User.new(
        database_client,
        { username: bobby_tables, host: '%' },
      )

      expect(database_client).to_not receive(:query).with(/bert'/)
      expect(database_client).to receive(:query).with(/bert\\'/)

      user.exists?
    end

    it 'should escape host before interpolating in sql string' do
      user = MysqlUsers::User.new(
        database_client,
        { username: 'marguerite', host: bobby_tables },
      )

      expect(database_client).to_not receive(:query).with(/bert'/)
      expect(database_client).to receive(:query).with(/bert\\'/)

      user.exists?
    end
  end

  context('#create') do
    let(:create_user_regex) { /^CREATE USER 'marguerite'@'%'$/ }

    it 'should create the user without password if no password given' do
      with_no_user_in_db
      expect(database_client).to receive(:query).with(create_user_regex)

      user.create
    end

    it 'should not create the user if it does exist' do
      with_user_in_db
      expect(database_client).to_not receive(:query).with(create_user_regex)

      user.create
    end

    it 'should create the user with password if password given' do
      with_no_user_in_db
      user = MysqlUsers::User.new(
        database_client,
        { username: 'u', host: '%', password: 'p' },
      )

      expect(database_client).to receive(:query).with(
        /^CREATE USER 'u'@'%' IDENTIFIED BY 'p'$/
      )

      user.create
    end

    it 'should escape interpolated password when creating' do
      with_no_user_in_db
      user = MysqlUsers::User.new(
        database_client,
        { username: 'u', host: '%', password: bobby_tables },
      )
      expect(database_client).to_not receive(:query).with(/bert'/)
      expect(database_client).to receive(:query).with(/^CREATE.*bert\\'/)

      user.create
    end
  end

  context('#drop') do
    let(:drop_user_sql) { %q{DROP USER 'marguerite'@'%'} }

    it 'should remove user from database if user exists' do
      with_user_in_db
      expect(database_client).to receive(:query).with(drop_user_sql)
      user.drop
    end

    it 'should not drop the user if it doesn\'t exist' do
      with_no_user_in_db
      expect(database_client).to_not receive(:query).with(drop_user_sql)
      user.drop
    end
  end

  context('#grant') do
    let(:grant_options) do
      {
        database: 'db',
        table: 'tbl',
        grants: [
          :select
        ]
      }
    end

    it 'should grant with full correct query (happy path)' do
      expect(database_client).to receive(:query).with(
        "GRANT select ON `db`.`tbl` TO 'marguerite'@'%'"
      )
      user.grant(grant_options)
    end

    it 'should grant to * if no database provided' do
      grant_options.delete(:database)
      expect(database_client).to receive(:query).with(/GRANT .* ON \*\.`tbl`/)
      user.grant(grant_options)
    end

    it 'should grant to * if no table provided' do
      grant_options.delete(:table)
      expect(database_client).to receive(:query).with(/GRANT .* ON `db`\.\*/)
      user.grant(grant_options)
    end

    it 'should surround table and db name in backticks' do
      expect(database_client).to receive(:query).with(/GRANT .* ON `db`\.`tbl`/)
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

    it 'should not run grant query if grant contains odd characters' do
      expect {
        user.grant(grant_options.merge({grants: ['&']}))
      }.to raise_error('grants should match [a-zA-Z ]. Refusing to give grants')
    end

    it 'should raise error if no grants specified' do
      grant_options.delete(:grants)
      expect { user.grant(grant_options) }.to raise_error(KeyError)
    end

    it 'should raise error if empty grants specified' do
      expect { user.grant(grant_options.merge({grants: []})) }
        .to raise_error('provided list of grants must be non-empty')
    end

    it 'should give all grants' do
      expect(database_client).to receive(:query).with(/^GRANT foo,bar/)
      user.grant(grant_options.merge({grants: [:foo, :bar]}))
    end

    it 'should give grants to the user' do
      expect(database_client).to receive(:query).with(
        /^GRANT .* TO 'marguerite'@'%'$/
      )
      user.grant(grant_options)
    end

    it 'should give give "with grant option" if required' do
      expect(database_client).to receive(:query).with(
        /^GRANT .* WITH GRANT OPTION$/
      )
      user.grant(grant_options.merge({with_grant_option: true}))
    end
  end

  context('#revoke') do
    let(:grant_options) do
      {
        database: 'db',
        table: 'tbl',
        grants: [
          :select
        ]
      }
    end

    it 'should revoke with full correct query (happy path)' do
      expect(database_client).to receive(:query).with(
        "REVOKE select ON `db`.`tbl` FROM 'marguerite'@'%'"
      )
      user.revoke(grant_options)
    end

    it 'should revoke from * if no database provided' do
      grant_options.delete(:database)
      expect(database_client).to receive(:query).with(/REVOKE .* ON \*\.`tbl`/)
      user.revoke(grant_options)
    end

    it 'should revoke from * if no table provided' do
      grant_options.delete(:table)
      expect(database_client).to receive(:query).with(/REVOKE .* ON `db`\.\*/)
      user.revoke(grant_options)
    end

    it 'should surround table and db name in backticks' do
      expect(database_client).to receive(:query).with(/REVOKE.* ON `db`\.`tbl`/)
      user.revoke(grant_options)
    end

    it 'should error if provided table name contains backticks' do
      expect(database_client).to_not receive(:query).with(/stompy`/)
      expect {
        user.revoke(grant_options.merge({table: 'stompy`'}))
      }.to raise_error(/refusing to revoke grants/)
    end

    it 'should error if provided database name contains `' do
      expect(database_client).to_not receive(:query).with(/stompy`/)
      expect {
        user.revoke(grant_options.merge({database: 'stompy`'}))
      }.to raise_error(/refusing to revoke grants/)
    end

    it 'should revoke all specified grants' do
      expect(database_client).to receive(:query).with(/^REVOKE foo,bar/)
      user.revoke(grant_options.merge({grants: [:foo, :bar]}))
    end

    it 'should not run revoke query if grant contains odd characters' do
      expect {
        user.revoke(grant_options.merge({grants: ['&']}))
      }.to raise_error('grants should match [a-zA-Z ]. Refusing to revoke grants')
    end

    it 'should raise error if no grants specified' do
      grant_options.delete(:grants)
      expect { user.revoke(grant_options) }.to raise_error(KeyError)
    end

    it 'should raise error if empty grants specified' do
      expect { user.revoke(grant_options.merge({grants: []})) }
        .to raise_error('provided list of grants must be non-empty')
    end

    it 'should revoke grants from the user' do
      expect(database_client).to receive(:query).with(
        /^REVOKE .* FROM 'marguerite'@'%'$/
      )
      user.revoke(grant_options)
    end
  end
end
