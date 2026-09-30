# SuccessFactors 직원 조회 Fiori 앱 (BTP ABAP + RAP + Fiori elements)

SAP BTP ABAP Environment의 RAP **Custom Entity**가 SuccessFactors OData V2 `User` 엔티티를 호출하고,
Fiori elements(List Report + Object Page) 앱이 그 결과를 보여주는 구조입니다.

```
Fiori elements 앱 ──OData V4──> RAP Service Binding ──> Custom Entity ZI_SF_EMPLOYEE
                                                          └ Query Provider ZCL_SF_EMPLOYEE_QUERY
                                                               └ (Communication Arrangement) ──HTTPS──> SuccessFactors /odata/v2/User
```

> **중요**: 이 소스는 작성 환경에 ABAP 시스템이 없어 **컴파일/실행 테스트를 하지 못했습니다.**
> ADT에 붙여넣은 뒤 Syntax check(Ctrl+F2)에서 나오는 오류는 릴리스 차이(메서드 시그니처 등)일 수 있으니 알려주시면 함께 고치겠습니다.

## 폴더 구성

| 경로 | 내용 |
|---|---|
| `abap/zi_sf_employee.asddls` | Custom Entity (필드 + UI 애노테이션 포함) |
| `abap/zcl_sf_employee_query.clas.abap` | Query Provider 클래스 (Mock/실제 SF 전환 스위치 포함) |
| `abap/zui_sf_employee.srvd` | Service Definition |
| `app/webapp/` | Fiori elements 앱 (`manifest.json`, `Component.js`, `i18n`, `index.html`) |
| `app/package.json`, `ui5.yaml`, `ui5-deploy.yaml` | 로컬 실행/배포 설정 |

## 1단계 – Mock 모드로 먼저 동작 확인 (SF 테넌트 불필요)

`ZCL_SF_EMPLOYEE_QUERY`의 `c_use_mock`이 기본값 `abap_true`라서 샘플 직원 8명으로 동작합니다.

1. **ADT**에서 ABAP Cloud Project(BTP 인스턴스) 연결 후 패키지 `ZSF_EMPLOYEE` 생성
2. 클래스 생성: `ZCL_SF_EMPLOYEE_QUERY` → 소스를 `zcl_sf_employee_query.clas.abap` 내용으로 교체 후 Activate
   (Custom Entity가 클래스를 참조하고 클래스가 엔티티를 참조하므로, 처음엔 **빈 클래스(IF_RAP_QUERY_PROVIDER 구현)를 먼저 만들고**, 엔티티를 activate한 뒤 클래스 소스를 채우는 순서가 안전합니다.)
3. Data Definition → *Custom Entity* 로 `ZI_SF_EMPLOYEE` 생성 → `zi_sf_employee.asddls` 내용 붙여넣고 Activate
4. Service Definition `ZUI_SF_EMPLOYEE` 생성 → `zui_sf_employee.srvd` 내용 붙여넣고 Activate
5. Service Binding `ZUI_SF_EMPLOYEE_O4` 생성 (Binding Type: **OData V4 – UI**, Service Definition: `ZUI_SF_EMPLOYEE`) → **Publish**
6. Service Binding 화면의 `Employee` 엔티티 → **Preview** 로 List Report 화면 확인

## 2단계 – Fiori 앱 배포 (BAS)

1. BAS **SAP Fiori 타입 Dev Space**에서 `app/` 폴더를 프로젝트로 가져오기 (또는 Application Generator로 같은 서비스를 소스로 새로 생성)
2. `ui5.yaml`의 backend URL(`<your-abap-instance>`)을 본인 ABAP 인스턴스 URL로 수정
3. `npm install` 후 `npm start`로 로컬 실행 확인
4. 배포: `ui5-deploy.yaml`의 URL/client/package/transport를 채우고 `npm run deploy`
5. Fiori Launchpad 노출은 BTP Work Zone 또는 ABAP 쪽 Business Catalog/Role 구성 필요
   (manifest의 inbound: 시맨틱 오브젝트 `zsfemployee`, 액션 `display`)

## 3단계 – 실제 SuccessFactors 연동으로 전환

### (a) SuccessFactors 쪽 준비
- API 호출용 계정(기술 사용자) 준비 및 **Role-Based Permission**에서 `User` 엔티티 읽기 권한 부여
  (Admin Center → *Manage Permission Roles* → Employee Data / User 관련 권한, 그리고 *Admin Center Permissions → Manage Integration Tools → Allow Admin to Access OData API through Basic Authentication*)
- 인증 방식 선택: OAuth 2.0 SAML Bearer(권장) 또는 Basic (`사용자ID@회사ID`)
- 데이터센터 API 호스트 확인 (예: `apisalesdemo8.successfactors.com`)

### (b) ABAP 쪽 Communication 구성
1. ADT에서 **Outbound Service** `ZSF_ODATA_REST` 생성 (Service Type: REST)
2. **Communication Scenario** `ZSF_ODATA_SCENARIO` 생성 → Outbound Service 탭에 위 서비스 추가 → Activate → **Publish Locally**
3. ABAP 인스턴스의 Fiori Launchpad → **Communication Systems** 앱에서 SF 시스템 등록
   (Host = SF API 호스트, Port 443, 인증 사용자 정보 입력)
4. **Communication Arrangements** 앱 → 시나리오 `ZSF_ODATA_SCENARIO` 선택 → 위 Communication System 연결 →
   Outbound Services 에서 `ZSF_ODATA_REST` 활성화 → Save

### (c) 스위치 변경
`ZCL_SF_EMPLOYEE_QUERY`에서 아래 한 줄을 변경 후 Activate:

```abap
c_use_mock TYPE abap_bool VALUE abap_false,
```

## 동작/제한 사항

- **서버 사이드 페이징**(`$top/$skip`), **총건수**(`$inlinecount`), **정렬**(`$orderby`)을 SF에 위임합니다.
- **필터는 `User ID`와 `Department`의 단일 값(EQ)만** SF로 전달합니다. 범위/여러 값 필터는 Mock 모드에서만 동작하며,
  실제 모드에서 필요하면 `if_rap_query_provider~select`의 필터 조립부를 확장하세요.
- `Full Name` 정렬은 SF의 `lastName` 기준으로 변환됩니다.
- JSON 파싱에 `/UI2/CL_JSON`을 사용합니다. 인스턴스에서 사용할 수 없으면 XCO(`xco_cp_json`)로 교체하면 됩니다.
- SF 응답이 200이 아니면 예외가 발생합니다. 원인은 ADT의 *Feed Reader / Application Log*, 또는 Communication Arrangement 설정을 확인하세요.
- 조회 전용(읽기) 앱입니다. 수정/생성이 필요하면 Custom Entity 대신 Unmanaged RAP BO로 확장해야 합니다.
