package [% module %];
use Mojo::Base qw< -base -signatures >;
use Ouch qw< :trytiny_var >;

has 'db_url';
has mdb => sub ($self) { $self->mdb_class->new($self->db_url) };

sub db ($self) { return $self->mdb->db }
sub mdb_engine ($s) { '' . ($s->db_url =~ m{postgres} ? 'Pg' : 'SQLite') }
sub mdb_module ($self) { 'Mojo::' . $self->mdb_engine }

sub mdb_class ($self) {
   my $class = $self->mdb_module;
   require("$class.pm" =~ s{::}{/}rgmxs);
   return $class;
}

# engine-specific method calls
sub _call ($self, $method, @args) {
   $method = join '_', $method, split m{\W+}mxs, $self->mdb_engine;
   return $self->$method(@args);
}

sub _recall ($self, @args) {
   my $prefix = (caller(1))[3] =~ s{\A .* ::}{}rmxs;
   $self->_call($prefix, @args);
}

sub id_of ($self, $table, $cond, $opts = undef) {
   my $hash = $self->db->select($table, ['id'], $cond, $opts // {})->hash;
   return $hash ? $hash->{id} : undef;
}

sub id_or_insert ($self, $table, $condition, $default, %opts) {
   for (1 .. 3) { # paranoia for quick insert/delete
      my $id = $self->id_of($table, $condition, $opts{select_options});
      return $id if defined($id);

      $id = $self->_try_insert_id($table, $default, $opts{insert_options});
      return $id if defined($id);
   }
   ouch 500, 'cannot select nor insert, bailing out',
      [ id_or_insert => $table, $condition, $default, %opts];
}

sub upsert ($self, $table, $data, $opts) {
   $self->db->insert($table, $data, { $opts->%*, on_conflict => $data });
   return $self;
}

# show what _recall is about
sub _try_insert_id ($self, @args) { $self->_recall(@args) }

sub _try_insert_id_SQLite ($self, $table, $data, $opts) {
   my %opts = (($opts // {})->%*, on_conflict => undef);
   return $self->db->insert($table, $data, \%opts)->last_insert_id;
}

sub _try_insert_id_Pg ($self, $table, $data, $opts) {
   my %opts = (($opts // {})->%*, returning => 'id', on_conflict => undef);
   return $self->db->insert($table, $data, \%opts)->hash->{id};
}

sub init ($self, $name) {
   $self->mdb->migrations->name($name)
      ->from_string($self->_call('_migration_text_for'))
      #->migrate(0)
      ->migrate;
   return $self;
}

sub _migration_text_for_Pg ($self) {
   return <<'END';
-- 1 up
CREATE TABLE account (
   id     SERIAL PRIMARY KEY,
   name   TEXT UNIQUE NOT NULL,
   secret TEXT NOT NULL
);
-- user foo with password 123
-- in Pg it is commented by default, assuming production
-- insert into account (name, secret) values ('foo', '$argon2id$v=19$m=262144,t=3,p=1$tl6bGS7qhnvv5pDNqXR2xg$5WQerdMu0TISaRpJZtTLCBp41wXI6NATzRXr82+5vPs');

-- 1 down
DROP TABLE account;
END
}

sub _migration_text_for_SQLite ($self) {
   return <<'END';
-- 1 up
CREATE TABLE account (
   id     INTEGER PRIMARY KEY,
   name   TEXT UNIQUE NOT NULL,
   secret TEXT NOT NULL
);
-- user foo with password 123
-- in SQLite it is enabled by default, assuming dev environment
insert into account (name, secret) values ('foo', '$argon2id$v=19$m=262144,t=3,p=1$tl6bGS7qhnvv5pDNqXR2xg$5WQerdMu0TISaRpJZtTLCBp41wXI6NATzRXr82+5vPs');

-- 1 down
DROP TABLE account;
END
}

1;
