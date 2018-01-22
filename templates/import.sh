#!/bin/bash
token=$(shield create-auth-token tmp)
shield import <( \
    bosh int templates/shield_targets.yml \
	 --vars-store=state/creds.yml \
	 --vars-file=vars.yml \
	 --var shield-token="${token}"
    
)
shield revoke-auth-token tmp
