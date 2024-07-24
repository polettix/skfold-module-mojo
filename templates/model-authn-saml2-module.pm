package [% module %];
use Mojo::Base qw< -base -signatures >;
use Net::SAML2;
use Net::SAML2::IdP;
use Net::SAML2::Protocol::AuthnRequest;
use Net::SAML2::Binding::Redirect;
use Net::SAML2::Binding::POST;
use Net::SAML2::Protocol::Assertion;
use Net::SAML2::XML::Sig;
use Ouch qw< :trytiny_var >;
use Try::Catch;
use JSON::PP qw< encode_json decode_json >;
use Storable qw< dclone >;
use Mojo::File qw< tempfile >;

use constant DEFAULT_TTL => 5 * 60; # 5 minutes default
use constant REQ_TTL     => 30;

has name => 'saml2';
has 'cache';
has 'ttl' => sub { DEFAULT_TTL };
has 'idp_configuration'; # configuration hash
has 'sp_configuration';  # configuration hash
has 'idp' => \&_build_idp;  # Net::SAML2::IdP instance

sub __get_cache ($wmdb) {
   if (defined($wmdb)) {
      require [% all_modules.model_authn_saml2_db_module %];
      return [% all_modules.model_authn_saml2_db_module %]->new(wmdb => $wmdb);
   }
   else {
      require [% all_modules.model_authn_saml2_hash_module %];
      return [% all_modules.model_authn_saml2_hash_module %]->new;
   }
}

sub create ($class, $model, %args) {
   $args{cache} //= __get_cache($model->wmdb);
   return $class->new(%args);
}

sub __key ($prefix, $x) { join '-', $prefix, (ref($x) ? $x->{key} : $x) }

sub cache_user ($self, $user, $ttl = undef) {
   my $key = __key(user => $user);
   my $expire = time() + ($ttl //= $self->ttl);
   $self->cache->set($user, $key, $expire);
   return $self;
}

sub wipe_user ($self, $user) { $self->cache->wipe(__key(user => $user)) }

sub load_user ($s, $key) { return $s->cache->get(__key(user => $key)) }

sub validate_user ($self, $name, $secret, $extra) {
   return defined($self->load_user($name)) ? $name : undef;
}

# build URL for redirecting to the IdP for authentication
sub _build_idp ($self) {
   my $meta = $self->idp_configuration->{metadata};
   return Net::SAML2::IdP->new_from_url(url => $meta)
      if $meta =~ m{\A (?: \w+) :// }imxs;
   return Net::SAML2::IdP->new_from_xml(xml => $meta);
}

# returns id of request and redirect URL
sub idp_login ($self) {
   my $idp_conf = $self->idp_configuration;
   my $sp_conf  = $self->sp_configuration;
   my $idp = $self->idp;

   my $sso_url = $idp->sso_url('urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect');

   my $assertion_url = $sp_conf->{'sso-post-url-override'} // undef;
   my $authnreq = Net::SAML2::Protocol::AuthnRequest->new(
      issuer        => $sp_conf->{identifier},
      destination   => $sso_url,
      (defined($assertion_url) ? (assertion_url => $assertion_url) : ()),
   );

   # Store the request's id for later verification
   my $id = $authnreq->id;
   my $key = __key(authnreq_id => $id);
   my $expire = time + REQ_TTL;
   $self->cache->set({ ts => $authnreq->issue_instant }, $key, $expire);

   my $sig_hash = $idp_conf->{sig_hash};
   my $redirect = Net::SAML2::Binding::Redirect->new(
      key   => $sp_conf->{key},    # to sign the redirect
      param => 'SAMLRequest',      # what's this about
      url   => $sso_url,           # where it's heading to
      (defined($sig_hash) ? (sig_hash => $sig_hash) : ()),
   );
   my $url = $redirect->sign($authnreq->as_xml);

   return ($id, $url);
}

sub parse_assertion ($self, $id, $response) {
   defined($id) or ouch 400, 'Not expecting anything SAML-related';
   my $reqts = $self->cache->get(__key(authnreq_id => $id))
      or ouch 400, 'Not expecting anything SAML-related';
   $reqts->{ts} + 30 < time()
      or ouch 400, 'Not expecting anything SAML-related';
   defined($response) or ouch 400, 'No SAMLResponse';

   my $sp_conf = $self->sp_configuration;
   my $xml_response = Net::SAML2::Binding::POST->new
      ->handle_response($response);

   # the module insists on a file-based CA certificate...
   my $cacert = tempfile();
   $cacert->spew(join "\n\n", $self->idp->cert('signing')->@*);
   my $assertion = Net::SAML2::Protocol::Assertion->new_from_xml(
      xml => $xml_response,
      key_file => $sp_conf->{key},
      cacert => $cacert,
   );
   $cacert->remove;

   $assertion->valid($sp_conf->{identifier}, $id)
     or ouch 400, 'Invalid SAMLResponse';

   my $uid = $assertion->nameid;
   my $user = $self->normalize_user({ $assertion->attributes->%*, key => $uid });

   $user->{groups} //= []; # TODO FIXME acquire groups...

   $self->cache_user($user);
   return $self;
}

sub normalize_user ($self, $user) {
   state $key_for = {
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname' => 'name',
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname' => 'surname',
   };
   for my $inkey (keys $key_for->%*) {
      next unless exists($user->{$inkey});
      my $vals = $user->{$inkey};
      my @values = ref($vals) ? $vals->@* : $vals;
      $user->{$key_for->{$inkey}} = join ', ', @values;
   }

   $user->{fullname} = join(' ', grep { defined } $user->@{qw< name surname >}) // '';

   return $user;
}

1;
