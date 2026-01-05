
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

# =============================================================================
# Unit Tests for AWS RAM Share Configuration
# =============================================================================
# Philosophy: Test YOUR API behavior, not the provider's API.
# - Conditional rendering: When flag X is set, these resources render
# - Configuration mapping: When flag Y is set, provider resources configure correctly
# - Default values: When field Z is omitted, it defaults appropriately
# - Edge cases: When A and B are set, the interaction produces expected output
# =============================================================================

_items = [

    # =========================================================================
    # Test: Basic RAMShare renders with correct defaults
    # =========================================================================
    # When: Minimal spec with required fields only
    # Then: ResourceShare renders with default managementPolicies, default providerConfig, default tags
    metav1alpha1.CompositionTest{
        metadata.name = "basic-ramshare-defaults"
        spec = {
            compositionPath = "apis/ramshares/composition.yaml"
            xrdPath = "apis/ramshares/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "RAMShare"
                metadata.name = "test-defaults"
                spec = {
                    region = "us-east-1"
                    name = "test-share"
                    resources = [{name = "res", arn = "arn:aws:ec2::123456789012:ipam-pool/pool-123"}]
                    principals = [{type = "account", name = "acct", id = "999999999999"}]
                }
            }
            assertResources = [
                # ResourceShare should have default managementPolicies and providerConfig
                {
                    apiVersion = "ram.aws.m.upbound.io/v1beta1"
                    kind = "ResourceShare"
                    metadata.name = "test-defaults"
                    spec = {
                        managementPolicies = ["*"]
                        providerConfigRef = {name = "default", kind = "ProviderConfig"}
                        forProvider = {
                            allowExternalPrincipals = False
                            tags = {hops = "true"}
                        }
                    }
                }
            ]
        }
    }

    # =========================================================================
    # Test: Custom providerConfigRef with kind=ClusterProviderConfig
    # =========================================================================
    # When: providerConfigRef.kind = ClusterProviderConfig
    # Then: ResourceShare uses the specified kind
    metav1alpha1.CompositionTest{
        metadata.name = "cluster-provider-config"
        spec = {
            compositionPath = "apis/ramshares/composition.yaml"
            xrdPath = "apis/ramshares/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "RAMShare"
                metadata.name = "test-cluster-pc"
                spec = {
                    region = "us-east-1"
                    name = "test-share"
                    providerConfigRef = {
                        name = "my-cluster-config"
                        kind = "ClusterProviderConfig"
                    }
                    resources = [{name = "res", arn = "arn:aws:ec2::123456789012:ipam-pool/pool-123"}]
                    principals = [{type = "account", name = "acct", id = "999999999999"}]
                }
            }
            assertResources = [
                {
                    apiVersion = "ram.aws.m.upbound.io/v1beta1"
                    kind = "ResourceShare"
                    metadata.name = "test-cluster-pc"
                    spec.providerConfigRef = {
                        name = "my-cluster-config"
                        kind = "ClusterProviderConfig"
                    }
                }
            ]
        }
    }

    # =========================================================================
    # Test: Tags merge with defaults
    # =========================================================================
    # When: Custom tags provided
    # Then: Tags merge with default "hops: true" tag
    metav1alpha1.CompositionTest{
        metadata.name = "tags-merge-with-defaults"
        spec = {
            compositionPath = "apis/ramshares/composition.yaml"
            xrdPath = "apis/ramshares/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "RAMShare"
                metadata.name = "test-tags"
                spec = {
                    region = "us-east-1"
                    name = "test-share"
                    resources = [{name = "res", arn = "arn:aws:ec2::123456789012:ipam-pool/pool-123"}]
                    principals = [{type = "account", name = "acct", id = "999999999999"}]
                    tags = {
                        Environment = "production"
                        Team = "platform"
                    }
                }
            }
            assertResources = [
                {
                    apiVersion = "ram.aws.m.upbound.io/v1beta1"
                    kind = "ResourceShare"
                    metadata.name = "test-tags"
                    spec.forProvider.tags = {
                        hops = "true"
                        Environment = "production"
                        Team = "platform"
                    }
                }
            ]
        }
    }

    # =========================================================================
    # Test: ResourceAssociation renders after ResourceShare is ready
    # =========================================================================
    # When: ResourceShare is observed as ready
    # Then: ResourceAssociation resources are created
    metav1alpha1.CompositionTest{
        metadata.name = "resource-association-after-share-ready"
        spec = {
            compositionPath = "apis/ramshares/composition.yaml"
            xrdPath = "apis/ramshares/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "RAMShare"
                metadata.name = "test-assoc"
                spec = {
                    region = "us-east-1"
                    name = "test-share"
                    resources = [
                        {name = "pool-1", arn = "arn:aws:ec2::123456789012:ipam-pool/pool-1"}
                        {name = "pool-2", arn = "arn:aws:ec2::123456789012:ipam-pool/pool-2"}
                    ]
                    principals = [{type = "account", name = "acct", id = "999999999999"}]
                }
            }
            observedResources = [
                {
                    apiVersion = "ram.aws.m.upbound.io/v1beta1"
                    kind = "ResourceShare"
                    metadata = {
                        name = "test-assoc"
                        annotations = {"crossplane.io/composition-resource-name" = "resource-share"}
                    }
                    status = {
                        conditions = [{type = "Ready", status = "True"}]
                        atProvider = {
                            arn = "arn:aws:ram:us-east-1:123456789012:resource-share/abc-123"
                            id = "arn:aws:ram:us-east-1:123456789012:resource-share/abc-123"
                        }
                    }
                }
            ]
            assertResources = [
                {
                    apiVersion = "ram.aws.m.upbound.io/v1beta1"
                    kind = "ResourceAssociation"
                    metadata.name = "test-assoc-pool-1"
                    spec.forProvider = {
                        resourceArn = "arn:aws:ec2::123456789012:ipam-pool/pool-1"
                        resourceShareArnRef.name = "test-assoc"
                    }
                }
                {
                    apiVersion = "ram.aws.m.upbound.io/v1beta1"
                    kind = "ResourceAssociation"
                    metadata.name = "test-assoc-pool-2"
                    spec.forProvider = {
                        resourceArn = "arn:aws:ec2::123456789012:ipam-pool/pool-2"
                        resourceShareArnRef.name = "test-assoc"
                    }
                }
            ]
        }
    }

    # =========================================================================
    # Test: PrincipalAssociation renders after ResourceShare is ready
    # =========================================================================
    # When: ResourceShare is observed as ready
    # Then: PrincipalAssociation resources are created
    metav1alpha1.CompositionTest{
        metadata.name = "principal-association-after-share-ready"
        spec = {
            compositionPath = "apis/ramshares/composition.yaml"
            xrdPath = "apis/ramshares/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "RAMShare"
                metadata.name = "test-prin"
                spec = {
                    region = "us-east-1"
                    name = "test-share"
                    resources = [{name = "res", arn = "arn:aws:ec2::123456789012:ipam-pool/pool-123"}]
                    principals = [
                        {type = "account", name = "acct-1", id = "111111111111"}
                        {type = "organizationalUnit", name = "teams-ou", arn = "arn:aws:organizations::123456789012:ou/o-abc/ou-root-teams"}
                    ]
                }
            }
            observedResources = [
                {
                    apiVersion = "ram.aws.m.upbound.io/v1beta1"
                    kind = "ResourceShare"
                    metadata = {
                        name = "test-prin"
                        annotations = {"crossplane.io/composition-resource-name" = "resource-share"}
                    }
                    status = {
                        conditions = [{type = "Ready", status = "True"}]
                        atProvider = {
                            arn = "arn:aws:ram:us-east-1:123456789012:resource-share/abc-123"
                            id = "arn:aws:ram:us-east-1:123456789012:resource-share/abc-123"
                        }
                    }
                }
            ]
            assertResources = [
                {
                    apiVersion = "ram.aws.m.upbound.io/v1beta1"
                    kind = "PrincipalAssociation"
                    metadata.name = "test-prin-acct-1"
                    spec.forProvider = {
                        principal = "111111111111"
                        resourceShareArnRef.name = "test-prin"
                    }
                }
                {
                    apiVersion = "ram.aws.m.upbound.io/v1beta1"
                    kind = "PrincipalAssociation"
                    metadata.name = "test-prin-teams-ou"
                    spec.forProvider = {
                        principal = "arn:aws:organizations::123456789012:ou/o-abc/ou-root-teams"
                        resourceShareArnRef.name = "test-prin"
                    }
                }
            ]
        }
    }

    # =========================================================================
    # Test: Associations don't render before ResourceShare is ready
    # =========================================================================
    # When: ResourceShare is NOT observed as ready
    # Then: No ResourceAssociation or PrincipalAssociation resources
    metav1alpha1.CompositionTest{
        metadata.name = "associations-wait-for-share"
        spec = {
            compositionPath = "apis/ramshares/composition.yaml"
            xrdPath = "apis/ramshares/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "RAMShare"
                metadata.name = "test-wait"
                spec = {
                    region = "us-east-1"
                    name = "test-share"
                    resources = [{name = "res", arn = "arn:aws:ec2::123456789012:ipam-pool/pool-123"}]
                    principals = [{type = "account", name = "acct", id = "999999999999"}]
                }
            }
            # No observed resources - share not ready
            observedResources = []
            # Only ResourceShare should render - associations are gated
            assertResources = [
                {
                    apiVersion = "ram.aws.m.upbound.io/v1beta1"
                    kind = "ResourceShare"
                    metadata.name = "test-wait"
                }
            ]
        }
    }

    # =========================================================================
    # Test: allowExternalPrincipals configuration
    # =========================================================================
    # When: allowExternalPrincipals = true
    # Then: ResourceShare has allowExternalPrincipals = true
    metav1alpha1.CompositionTest{
        metadata.name = "allow-external-principals"
        spec = {
            compositionPath = "apis/ramshares/composition.yaml"
            xrdPath = "apis/ramshares/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "RAMShare"
                metadata.name = "test-external"
                spec = {
                    region = "us-east-1"
                    name = "test-share"
                    allowExternalPrincipals = True
                    resources = [{name = "res", arn = "arn:aws:ec2::123456789012:ipam-pool/pool-123"}]
                    principals = [{type = "account", name = "acct", id = "999999999999"}]
                }
            }
            assertResources = [
                {
                    apiVersion = "ram.aws.m.upbound.io/v1beta1"
                    kind = "ResourceShare"
                    metadata.name = "test-external"
                    spec.forProvider.allowExternalPrincipals = True
                }
            ]
        }
    }

    # =========================================================================
    # Test: Organization principal type
    # =========================================================================
    # When: Principal type is organization
    # Then: PrincipalAssociation uses the organization ARN
    metav1alpha1.CompositionTest{
        metadata.name = "organization-principal"
        spec = {
            compositionPath = "apis/ramshares/composition.yaml"
            xrdPath = "apis/ramshares/definition.yaml"
            timeoutSeconds = 120
            validate = True
            xr = {
                apiVersion = "aws.hops.ops.com.ai/v1alpha1"
                kind = "RAMShare"
                metadata.name = "test-org"
                spec = {
                    region = "us-east-1"
                    name = "test-share"
                    resources = [{name = "res", arn = "arn:aws:ec2::123456789012:ipam-pool/pool-123"}]
                    principals = [{
                        type = "organization"
                        name = "entire-org"
                        arn = "arn:aws:organizations::123456789012:organization/o-abc123"
                    }]
                }
            }
            observedResources = [
                {
                    apiVersion = "ram.aws.m.upbound.io/v1beta1"
                    kind = "ResourceShare"
                    metadata = {
                        name = "test-org"
                        annotations = {"crossplane.io/composition-resource-name" = "resource-share"}
                    }
                    status = {
                        conditions = [{type = "Ready", status = "True"}]
                        atProvider = {
                            arn = "arn:aws:ram:us-east-1:123456789012:resource-share/abc-123"
                            id = "arn:aws:ram:us-east-1:123456789012:resource-share/abc-123"
                        }
                    }
                }
            ]
            assertResources = [
                {
                    apiVersion = "ram.aws.m.upbound.io/v1beta1"
                    kind = "PrincipalAssociation"
                    metadata.name = "test-org-entire-org"
                    spec.forProvider.principal = "arn:aws:organizations::123456789012:organization/o-abc123"
                }
            ]
        }
    }

]

items = _items
