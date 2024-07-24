package [% module %];
use Mojo::Base qw< -base -signatures >;
use Crypt::Passphrase;
use Mojo::File;
use Mojo::JSON qw< decode_json >;
use Ouch qw< :trytiny_var >;

has 'crypt_passphrase_options' => undef;
has crypt_passphrase => sub ($self) {
   return Crypt::Passphrase->new(
      encoder => 'Argon2',
      ($self->crypt_passphrase_options // {})->%*
   );
};

sub ensure_hashed ($self, $secret) {
   my $cp = $self->crypt_passphrase;
   $cp->needs_rehash($secret) ? $cp->hash_password($secret) : $secret;
}

sub validate_user ($self, $name, $secret, $extra) {
   my $user = $self->load_user_by_name($name) or return;
   my $cp = $self->crypt_passphrase;
   my $check = $cp->verify_password($secret, $user->{secret});
   return $check ? $name : undef;  # externally visible id is $name
}

1;
