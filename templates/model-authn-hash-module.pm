package [% module %];
use Mojo::Base qw< [% all_modules.model_authn_local_module %] -signatures >;
use Mojo::File;
use Mojo::JSON qw< decode_json >;
use Ouch qw< :trytiny_var >;
use Scalar::Util qw< refaddr >;

# Hardwired hash-based db, disabled by default. See below for an example.
use constant DEFAULT_DB => [
#      { name => foo => secret => 123  },
      { name => bar => secret => 456  },
#      { name => baz => secret => 789  },
#      { name => galook => secret => 0 },
];

# pass an explicit undef value to shut this module off
has db  => sub { DEFAULT_DB };
has _db => \&_build__db;

has _build__db => sub ($self) {
   my $db = $self->db;
   return unless length($db // '');

   if (! ref($db)) { # passed in as a JSON string or a file path?
      $db = Mojo::File->new($db)->slurp if $db !~ m{\A \s* \[ }mxs;
      $db = decode_json($db);
   }
   elsif (refaddr($db) == refaddr(DEFAULT_DB)) { # DEFAULT_DB?
      $db = [ # make sure to hash all secrets
         map {
            my $hashed_secret = $self->ensure_hashed($_->{secret});
            +{ $_->%*, secret => $hashed_secret };
         } $db->@*
      ];
   }
   else {} # $db is an externally-provided reference

   return $db if ref($db) eq 'HASH';
   return { map { $_->{name} => $_ } $db->@* };
};

sub load_user ($self, $name) {
   defined(my $db = $self->_db) or return;
   return unless exists($db->{$name});
   return { $db->{$name}->%* }; # shallow copy
}

*{load_user_by_name} = \&load_user;

sub save_user ($self, $user) {
   defined(my $db = $self->_db) or return;
   my $hashed_secret = $self->ensure_hashed($user->{secret});
   $db->{$user->{name}} = { $user->%*, secret => $hashed_secret };
   return $self;
}

1;
