# ABSTRACT: Simple Ad-Hoc Data Validation

package Validation::Class::Simple;

use strict;
use warnings;

use Validation::Class ();
use Validation::Class::Prototype;

use Validation::Class::Util ('prototype_registry');

# VERSION

=head1 SYNOPSIS

    use Validation::Class::Simple;

    # define object specific rules
    my $rules = Validation::Class::Simple->new(
        # define fields on-the-fly
        fields => {
            name  => { required => 1 },
            email => { required => 1 },
            pass  => { required => 1 },
            pass2 => { required => 1, matches => 'pass' },
        }
    );

    # set parameters to be validated
    $rules->params->add($parameters);

    # validate
    unless ($rules->validate) {
        # handle the failures
    }

=head1 DESCRIPTION

Validation::Class::Simple is a simple validation module built around the powerful
L<Validation::Class> data validation framework.

This module is merely a blank canvas, a clean validation class derived from
L<Validation::Class> which has not been pre-configured (e.g. configured via
keywords, etc).

It can be useful in an environment where you wouldn't care to create a
validation class and instead would simply like to pass rules to a validation
engine in an ad-hoc fashion.

=head1 QUICKSTART

If you are looking for a data validation module with an even lower learning curve
built using the same tenets and principles as Validation::Class which is as
simple and even lazier than this module, please review the tested but
experimental L<Validation::Class::Simple::Streamer>.

=head1 RATIONALE

If you are new to Validation::Class, or would like more information on the
underpinnings of this library and how it views and approaches data validation,
please review L<Validation::Class::Whitepaper>.

=head1 GUIDED TOUR

The instructions contained in this documentation are also relevant for
configuring any class derived from L<Validation::Class>. The validation logic
that follows is not specific to a particular use-case.

=head2 Parameter Handling

There are three ways to declare parameters you wish to have validated. The first
and most common approach is to supply the target parameters to the validation
class constructor:

    use Validation::Simple;

    my $rules = Validation::Simple->new(params => $parameters);

All input parameters are wrapped by the L<Validation::Class::Params> container
which provides generic functionality for managing hashes. Additionally you can
declare parameters by using the params object directly:

    use Validation::Simple;

    my $rules = Validation::Simple->new;

    $rules->params->clear;

    $rules->params->add(user => 'admin', pass => 's3cret');

    printf "%s parameters were submitted", $rules->params->count;

Finally, any parameter which has corresponding validation rules that has been
declared in a validation class derived from L<Validation::Class> will have an
accessor which can be used directly or as an argument to the constructor:

    package MyApp::Person;

    use Validation::Class;

    field 'name' => {
        required => 1
    };

    package main;

    my $rules = MyApp::Person->new(name => 'Egon Spangler');

    $rules->name('Egon Spengler');

=head2 Validation Rules

Validation::Class comes with a complete standard set of validation rules which
allows you to easily describe the constraints and operations that need to be
performed per parameter.

Validation rules are referred to as I<fields>, fields are named after the
parameters they expect to be matched against. A field is also a hashref whose
keys are called directives which correspond with the names of classes in the
directives namespace, and whose values are arguments which control how
directives carry-out their operations.

    use Validation::Simple;

    my $rules = Validation::Simple->new;

    $rules->fields->clear;

    $rules->fields->add(name => { required => 1, max_length => 255 });

Fields can be specified as an argument to the class constructor, or managed
directly using the L<Validation::Class::Fields> container. Every field is
wrapped by the L<Validation::Class::Field> container which provides accessors
for all core directives. Directives can be found under the directives namespace,
e.g. the required directive refers to L<Validation::Class::Directive::Required>.
Please see L<Validation::Class::Directives> for a list of all core directives.

=head2 Flow Control

A good data validation tool is not simply checking input against constraints,
its also providing a means to easily handle different and often complex data
input scenarios.

The queue method allows you to designate and defer fields to be validated. It
also allows you to set fields that must be validated regardless of what has been
passed to the validate method. Additionally it allows you to conditionally
specify constraints:

    use Validation::Simple;

    my $rules = Validation::Simple->new;

    $rules->queue('name'); # always validate the name parameter

    $rules->queue('email', 'email2') if $rules->param('change_email');
    $rules->queue('login', 'login2') if $rules->param('change_login');

    # validate name
    # validate email and email confirmation if change_email is true
    # validate login and login confirmation if change_login is true

    $rules->validate('password'); # additionally, validate password
    $rules->clear_queue;          # reset the queue when finished

Akin to the queue method is the stash method. At-times it is necessary to break
out of the box in order to design constraints that fit your particular use-case.
The stash method allows you to share arbitrary objects with routines used by
validation classes.

    use Validation::Simple;

    my $rules = Validation::Simple->new;

    $rules->fields->add(
        email => {
            # email validation relies on a stashed object
            validation => sub {
                my ($self, $field, $params) = @_;
                return 0 if ! my $dbo = $self->stash('dbo');
                return 0 if ! $dbo->email_exists($field->value);
                return 1;
            }
        }
    );

    # elsewhere in the program
    $rules->stash(dbo => $database_object); # stash the database object

=head2 Error Handling

When validation fails, and it will, you need to be able to report what failed
and why. L<Validation::Class> give you complete control over error handling and
messages. Errors can exist at the field-level and class-level (errors not
specific to a particular field). All errors are wrapped in a
L<Validation::Class::Errors> container.

    use Validation::Simple;

    my $rules = Validation::Simple->new;

    # print a comma separated list of class and field errors
    print $rules->errors_to_string unless $rules->validate;

    # print a newline separated list of class and field errors
    print $rules->errors_to_string("\n") unless $rules->validate;

    # print a comma separated list of class and upper-cased field errors
    print $rules->errors_to_string(undef, sub{ ucfirst lc shift })

    # print total number of errors at the class and field levels
    print "Found %s errors", $rules->error_count;

    # return a hashref of fields with errors
    my $errors = $rules->error_fields;

    # get errors for specific fields only
    my @errors = $rules->get_errors('email', 'login');

=head2 Input Filtering

Filtering data is one fringe benefits of a good data validation framework. The
process is also known as scrubbing or sanitizing data. The process ensures that
the data being passed to the business logic will be clean and consistent.

Filtering data is not as simple and straight-forward as it may seem which is why
it is necessary to think-through your applications interactions before
implementation.

Filtering is the process of applying transformations to the incoming data. The
problem with filtering is that it permanently alters the data input and in the
event of a failure could report inconsistent error messages:

    use Validation::Simple;

    my $rules = Validation::Simple->new;

    $rules->fields->add(
        # even if the input is submitted as lowercase it will fail
        # the filter is run as a pre-process by default
        username => {
            filters => ['uppercase'],
            validation => sub {
                return 0 if $_[1]->value =~ /[A-Z]/;
                return 1;
            }
        }
    );

When designing a system to filter data, it is always necessary to differentiate
pre-processing filters from post-processing filters. L<Validation::Class>
provides a filtering directive which designates certain fields to run filters in
post-processing:

    $rules->fields->add(
        # if the input is submitted as lowercase it will pass
        username => {
            filters => ['uppercase'],
            filtering => 'post',
            validation => sub {
                return 0 if $_[1]->value =~ /[A-Z]/;
                return 1;
            }
        }
    );

=head2 Handling Failures

A data validation framework exists to handle failures, it is its main function
and purpose, in-fact, the difference between a validation framework and a
type-constraint system is how it responds to errors.

When a type-constraint system finds an error it raises an exception. Exception
handling is the process of responding to the occurrence, during computation, of
exceptions (anomalous or exceptional situations).

Typically the errors reported when an exception is raised includes a dump of the
program's state up until the point of the exception which is apropos as exceptions
are unexpected.

A data validation framework can also be thought-of as a type system but one that
is specifically designed to expect input errors and report user-friendly error
messages.

L<Validation::Class> may encounter exceptions as programmers defined validation
rules which remain mutable. L<Validation::Class> provides attributes for
determining how the validation engine reacts to exceptions and validation
failures:

    use Validation::Simple;

    my $rules = Validation::Simple->new(
        ignore_failure => 1, # do not throw errors if validation fails
        ignore_unknown => 0, # throw errors if unknown directives are found
        report_failure => 0, # register errors if "method validations" fail
        report_unknown => 0, # register errors if "unknown directives" are found
    );

=head2 Data Validation

Once your fields are defined and you have your parameter rules configured as
desired you will like use the validate method to perform all required operations.
The validation operations occur in the following order:

    normalization   (resetting fields, clearing existing errors, etc)
    pre-processing  (applying filters, etc)
    validation      (processing directives, etc)
    post-processing (applying filters, etc)

What gets validated is determined by the state and arguments passed to the
validate method. The validate method determines what to validate in the
following order:

    checks the validation queue for fields
    checks arguments for regular expression objects and adds matching fields
    validates fields with matching parameters if no fields are specified
    validates all fields if no parameters are specified

It is also important to under what it means to declare a field as being required.
A field is a data validation rule matching a specific parameter, A required
field simply means that if-and-when a parameter is submitted, it is required to
have a value. It does not mean that a field is always required to be validated.

Occasionally you may need to temporarily set a field as required or
not-required for a specific validation operation. This requirement is referred
to as the toggle function. The toggle function is enacted by prefixing a field
name with a plus or minus sign (+|-) when passed to the validate method:

    use Validation::Simple;

    my $rules = Validation::Simple->new(fields => {...});

    # meaning, email is always required to have a value
    # however password and password2 can be submitted as empty strings
    # but if password and password2 have values they will be validated
    $rules->validate('+email', '-password', '-password2');

Here are a few examples and explanations of using the validate method:

    use Validation::Simple;

    my $rules = Validation::Simple->new(fields => {...});

    unless ($rules->validate) {
        # validate all fields with matching parameters
    }

    unless ($rules->validate) {
        # validate all fields because no parameters were submitted
    }

    unless ($rules->validate(qr/^email/)) {
        # validate all fields whose name being with email
        # e.g. email, email2, email_update
    }

    unless ($rules->validate('login', 'password')) {
        # validate the login and password specifically
        # regardless of what parameters have been set
    }

    unless ($rules->validate({ user => 'login', pass => 'password' })) {
        # map user and pass parameters to the appropriate fields as aliases
        # and validate login and password fields using the aliases
    }

=cut

sub new {

    my $class = shift;

    $class = ref $class || $class;

    my $self = bless {}, $class;

    prototype_registry->add(
        "$self" => Validation::Class::Prototype->new(
            package => $class # inside-out prototype
        )
    );

    # let Validation::Class handle arg processing
    $self->Validation::Class::initialize_validator(@_);

    return $self;

}

{

    no strict 'refs';

    # inject prototype class aliases unless exist

    my @aliases = Validation::Class::Prototype->proxy_methods;

    foreach my $alias (@aliases) {

        *{$alias} = sub {

            my ($self, @args) = @_;

            $self->prototype->$alias(@args);

        };

    }

    # inject wrapped prototype class aliases unless exist

    my @wrapped_aliases = Validation::Class::Prototype->proxy_methods_wrapped;

    foreach my $alias (@wrapped_aliases) {

        *{$alias} = sub {

            my ($self, @args) = @_;

            $self->prototype->$alias($self, @args);

        };

    }

}

sub proto { goto &prototype } sub prototype {

    return prototype_registry->get(shift);

}

sub DESTROY {

    my ($self) = @_;

    prototype_registry->delete($self) if $self && prototype_registry;

    return;

}

=head1 PROXY METHODS

Each instance of Validation::Class::Simple is associated with a *prototype*
class which provides the data validation engine and keeps the class namespace
free from pollution and collisions, please see L<Validation::Class::Prototype>
for more information on specific methods and attributes.

Validation::Class::Simple is injected with a few proxy methods which are
basically aliases to the corresponding prototype (engine) class methods, however
it is possible to access the prototype directly using the proto/prototype
methods.

=proxy_method class

    $self->class;

See L<Validation::Class::Prototype/class> for full documentation.

=proxy_method clear_queue

    $self->clear_queue;

See L<Validation::Class::Prototype/clear_queue> for full documentation.

=proxy_method error_count

    $self->error_count;

See L<Validation::Class::Prototype/error_count> for full documentation.

=proxy_method error_fields

    $self->error_fields;

See L<Validation::Class::Prototype/error_fields> for full documentation.

=proxy_method errors

    $self->errors;

See L<Validation::Class::Prototype/errors> for full documentation.

head2 errors_to_string

    $self->errors_to_string;

See L<Validation::Class::Prototype/errors_to_string> for full
documentation.

=proxy_method get_errors

    $self->get_errors;

See L<Validation::Class::Prototype/get_errors> for full documentation.

=proxy_method get_fields

    $self->get_fields;

See L<Validation::Class::Prototype/get_fields> for full documentation.

=proxy_method get_params

    $self->get_params;

See L<Validation::Class::Prototype/get_params> for full documentation.

=proxy_method fields

    $self->fields;

See L<Validation::Class::Prototype/fields> for full documentation.

=proxy_method filtering

    $self->filtering;

See L<Validation::Class::Prototype/filtering> for full documentation.

=proxy_method ignore_failure

    $self->ignore_failure;

See L<Validation::Class::Prototype/ignore_failure> for full
documentation.

=proxy_method ignore_unknown

    $self->ignore_unknown;

See L<Validation::Class::Prototype/ignore_unknown> for full
documentation.

=proxy_method param

    $self->param;

See L<Validation::Class::Prototype/param> for full documentation.

=proxy_method params

    $self->params;

See L<Validation::Class::Prototype/params> for full documentation.

=proxy_method queue

    $self->queue;

See L<Validation::Class::Prototype/queue> for full documentation.

=proxy_method report_failure

    $self->report_failure;

See L<Validation::Class::Prototype/report_failure> for full
documentation.

=proxy_method report_unknown

    $self->report_unknown;

See L<Validation::Class::Prototype/report_unknown> for full documentation.

=proxy_method reset_errors

    $self->reset_errors;

See L<Validation::Class::Prototype/reset_errors> for full documentation.

=proxy_method reset_fields

    $self->reset_fields;

See L<Validation::Class::Prototype/reset_fields> for full documentation.

=proxy_method reset_params

    $self->reset_params;

See L<Validation::Class::Prototype/reset_params> for full documentation.

=proxy_method set_errors

    $self->set_errors;

See L<Validation::Class::Prototype/set_errors> for full documentation.

=proxy_method set_fields

    $self->set_fields;

See L<Validation::Class::Prototype/set_fields> for full documentation.

=proxy_method set_params

    $self->set_params;

See L<Validation::Class::Prototype/set_params> for full documentation.

=proxy_method set_method

    $self->set_method;

See L<Validation::Class::Prototype/set_method> for full documentation.

=proxy_method stash

    $self->stash;

See L<Validation::Class::Prototype/stash> for full documentation.

=proxy_method validate

    $self->validate;

See L<Validation::Class::Prototype/validate> for full documentation.

=proxy_method validate_method

    $self->validate_method;

See L<Validation::Class::Prototype/validate_method> for full documentation.

=proxy_method validate_profile

    $self->validate_profile;

See L<Validation::Class::Prototype/validate_profile> for full documentation.

=head1 EXTENSIBILITY

Validation::Class does NOT provide method modifiers but can be easily extended
with L<Class::Method::Modifiers>.

=head2 before

    before foo => sub { ... };

See L<< Class::Method::Modifiers/before method(s) => sub { ... } >> for full
documentation.

=head2 around

    around foo => sub { ... };

See L<< Class::Method::Modifiers/around method(s) => sub { ... } >> for full
documentation.

=head2 after

    after foo => sub { ... };

See L<< Class::Method::Modifiers/after method(s) => sub { ... } >> for full
documentation.

=cut

1;
