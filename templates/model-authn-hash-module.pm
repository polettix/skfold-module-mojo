package [% module %];
use Mojo::Base qw< [% all_modules.model_authn_local_module %] -signatures >;
use Mojo::File;
use Mojo::JSON qw< decode_json >;
use Ouch qw< :trytiny_var >;
use Scalar::Util qw< refaddr >;

has 'db';
has name => 'hashy';

sub create ($class, $model, %args) {
   my $db = $args{db} or return;

   # create an instance, leave db unset for the moment
   my $self = $class->new;

   if (! ref($db)) { # passed in as a JSON string or a file path?
      $db = Mojo::File->new($db)->slurp if $db !~ m{\A \s* \[ }mxs;
      $db = decode_json($db);
   }

   if (! $args{secrets_already_hashed}) {  # need hashing?
      $db = [
         map {
            my $hashed_secret = $self->ensure_hashed($_->{secret});
            +{ $_->%*, secret => $hashed_secret };
         } $db->@*
      ];
   }

   # normalize to hash reference name => record
   $db = { map { $_->{name} => $_ } $db->@* } if ref($db) eq 'ARRAY';

   $self->db($db);
   return $self;
}

sub load_user ($self, $name) {
   my $item = $self->db->{$name} // return;
   return { $item->%* }; # shallow copy
}

*{load_user_by_id}   = \&load_user;
*{load_user_by_name} = \&load_user;

sub save_user ($self, $user) {
   my $hashed_secret = $self->ensure_hashed($user->{secret});
   $self->db->{$user->{name}} = { $user->%*, secret => $hashed_secret };
   return $self;
}

1;
