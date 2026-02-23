```yaml
easy_setup:
  flavors:
    dev:
      bundle_id: com.example.app.dev
      name: MyApp Dev
    staging:
      bundle_id: com.example.app.staging
      name: MyApp Staging
      provisioning_profile:
        debug:
          name: Dev Profile
        profile:
          name: Profile Profile
        release:
          name: Release Profile
    prod:
      bundle_id: com.example.app
      name: MyApp
      provisioning_profile:
        debug:
          name: Dev Profile
        profile:
          name: Profile Profile
        release:
          name: Release Profile
  ci_cd:
    # optional
    # 해당 필드를 입력 안하면 easy_setup.flavors에서 설정한 값이 사용됩니다.
    flavors:
      dev:
        bundle_id: com.example.app.dev
      staging:
        bundle_id: com.example.app.staging
      prod:
        bundle_id: com.example.app
    ios:
      #required
      storage: https://github.com/lwbvv/app-certification.git
#      # optional
#      # developer account (apple email)
#      apple_id: apple_id
      # required
      team_id: team_id
      # required
      itc_team_id: itc_team_id
      # optional
      # api key가 없을 경우에는 비밀번호를 물어본다
      api_key:
        # required
        id: api_key_id
        # required
        issuer_id: api_key_issuer_id
        # required
        # p8 파일 경로
        key_path: api_key_path
        # optional
        # 키 유효 시간 기본값 (1200초)
        duration: 1200
        # optional
        # 기본값 false
        # Enterprise 계정이 아니면 false
        in_house: false
    # required
    provisioning_profile:
      debug:
        # optional
        # 입력 안 했을 때 디폴트로 해당 값이 쓰임 (match Development #{app_bundle_id})
        name: Dev Profile
        # optional
        path: Profile Path
      profile:
        # 입력 안 했을 때 디폴트로 해당 값이 쓰임 (match Development #{app_bundle_id})
        name: Profile Profile
        path: Profile Path
      release:
        # 입력 안 했을 때 디폴트로 해당 값이 쓰임 (match Development #{app_bundle_id})
        name: Release Profile
        path: Profile Path
    
```