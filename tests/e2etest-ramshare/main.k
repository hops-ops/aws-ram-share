# e2etest-ramshare - Share IPAM pool with test account via RAM
# =============================================================
# Tests RAMShare's ability to create RAM resource shares.
# This test shares existing IPAM pools (from aws-ipam e2e) with the test account.
#
# Prerequisites:
# - Run aws-ipam e2e test first to create the IPAM pools
# - AWS credentials in secrets/aws-creds
#
# The test creates a RAM share that:
# 1. Shares the regional IPv4 IPAM pool
# 2. Grants access to the test account (from aws-organization e2e)

import base64
import file
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1

_creds = file.read("secrets/aws-creds")
_base64_creds = base64.encode(_creds)

# =============================================================================
# Configuration - IDs from existing e2e resources
# =============================================================================

_share_name = "hops-e2e-ramshare"
_region = file.read("env/AWS_REGION").strip()

# Existing test account (from aws-organization e2e test)
_source_account_id = file.read("env/AWS_ACCOUNT_ID").strip()
_destination_account_id = file.read("env/DESTINATION_ACCOUNT_ID").strip()

# Existing IPAM pool ARNs (from aws-ipam e2e test)
# Get pool ARN: aws ec2 describe-ipam-pools --query 'IpamPools[*].[IpamPoolId,IpamPoolArn]'
_ipv4_regional_pool_id = file.read("env/IPAM_POOL_REGIONAL_IPV4").strip()
_ipv4_regional_pool_arn = file.read("env/IPAM_POOL_REGIONAL_IPV4_ARN").strip()


# Existing test OU (from aws-organization e2e test)
_test_ou_arn = file.read("env/TEST_OU_ARN").strip()

# =============================================================================
# E2E Test Definition
# =============================================================================

_ramshare_manifest = {
    apiVersion: "aws.hops.ops.com.ai/v1alpha1"
    kind: "RAMShare"
    metadata: {
        name: _share_name
        namespace: "default"
    }
    spec: {
        region: _region
        name: _share_name + "-ipam-pool"
        allowExternalPrincipals: False

        providerConfigRef: {
            name: "default"
            kind: "ProviderConfig"
        }

        # Share the regional IPAM pool
        resources: [
            {
                name: "ipv4-regional"
                arn: _ipv4_regional_pool_arn
            }
        ]

        # Share with the test account
        principals: [
            {
                name: "test-account"
                type: "account"
                id: _destination_account_id
            }
        ]

        tags: {
            "e2etest": "true"
            "managed-by": "crossplane"
            "purpose": "ram-share-e2e-test"
        }
    }
}

_items = [
    metav1alpha1.E2ETest{
        metadata.name: ""
        spec = {
            crossplane.autoUpgrade.channel: "Rapid"
            defaultConditions: ["Ready"]
            manifests: [_ramshare_manifest]
            extraResources: [
                {
                    apiVersion: "v1"
                    kind: "Secret"
                    metadata: {
                        name: "aws-creds"
                        namespace: "default"
                    }
                    data: {
                        creds: _base64_creds
                    }
                },
                {
                    apiVersion: "aws.m.upbound.io/v1beta1"
                    kind: "ProviderConfig"
                    metadata: {
                        name: "default"
                        namespace: "default"
                    }
                    spec: {
                        credentials: {
                            source: "Secret"
                            secretRef: {
                                namespace: "default"
                                name: "aws-creds"
                                key: "creds"
                            }
                        }
                    }
                }
            ]
            skipDelete: False
            timeoutSeconds: 4500
        }
    }
]
items = _items
