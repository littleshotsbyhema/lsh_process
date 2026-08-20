# Architecture

## Core Principle

The database and server layer enforce business truth. The browser must not be trusted to enforce authorization or lifecycle rules.

## Security Model

Authentication -> Organization Membership -> Role -> Permission -> RLS -> Approved server/RPC operation -> Business validation -> Transaction -> Audit event

Required:
- organization_id on tenant-owned entities where applicable
- tenant-safe RLS
- permission-aware controlled writes
- no service-role exposure in client code
- server-only secrets

## Domain Boundaries

### Organisation
organizations
organization_members
roles
permissions
role_permissions
member_roles
invitations
organization_settings

### Family
families
family_contacts
contact_channels
communication_preferences
children
family_relationships

### Memory
memory_profiles
memory_events
milestones
memory_goals
memory_tags
future_memory_intents

### CRM
leads
lead_events
lead_tasks
consultations

### Commercial
services
packages
package_versions
package_inclusions
package_prices
package_addons
quotes
quote_versions
bookings
payments
refunds

### Trust
privacy_preferences
consent_records
consent_assets
consent_channels
consent_withdrawals
safety_records
terms_acceptances

### Production
shoots
shoot_assignments
shoot_setups
production_jobs
production_tasks
editing_batches
editing_reviews
delivery_jobs

### Heirloom
heirloom_orders
albums
album_versions
album_proofs
client_approvals
print_orders
frame_orders
production_checks
handover_records

## Integration Boundary

Third-party systems are adapters, not sources of business truth.

Adapters may include:
- AIProvider
- MessagingProvider
- PaymentProvider
- GalleryProvider
- StorageProvider

Pixieset, WhatsApp, payment gateways, and AI providers must remain replaceable behind domain-owned contracts.
