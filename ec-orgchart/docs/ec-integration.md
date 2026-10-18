# 조직도를 SuccessFactors Employee Central에 연동

이 프로토타입은 샘플 데이터로 구동됩니다. 모든 데이터 접근은 `webapp/model/OrgLogic.js` 의 세 가지 함수(`getTree`, `getUnit`, `getMembers`)를 거쳐 이루어집니다.
시스템을 실운영 환경으로 전환하려면, SuccessFactors OData API를 기반으로 이 세 함수를 다시 구현하되 기존 함수의 반환 데이터 구조(Shape)를 유지하면 됩니다.
이렇게 하면 뷰(View)와 컨트롤러(Controller)를 수정 없이 그대로 사용할 수 있습니다.

> 상태: 여기에 기재된 내용은 SuccessFactors 테넌트(Tenant)를 대상으로 실제로 실행된 적이 없습니다(접근 가능한 환경이 없었음).
> 아래의 엔티티 및 필드 이름은 **Employee Central의 일반적인 지식을 바탕으로 제안된 후보군** 입니다.
> 구현하기 전에 테넌트의 *API Center > OData API Data Dictionary* 에서 모든 이름을 반드시 확인하십시오. 필드 제공 여부는 테넌트 구성에 따라 다를 수 있습니다.

## 1. 연결(Connection)

```
브라우저 (본 앱) -> BTP Destination -> SuccessFactors OData API (V2)  https://<api-host>/odata/v2/
```

* 테넌트의 API 서버를 가리키는 BTP **Destination** 을 생성합니다. 일반적으로 로그인한 사용자의 권한이
  SF RBP(역할 기반 권한)에 그대로 적용되도록 OAuth 2.0 SAML Bearer 방식을 선택합니다. (Basic 인증은 테스트 용도로만 적합합니다.)
* SF 내에서 연동 사용자 또는 OAuth 클라이언트는 아래 엔티티들에 대한 읽기 권한이 필요합니다.
  (Admin Center의 *Manage Permission Roles* / *Manage OAuth2 Client Applications* 에서 설정)
* 광범위한 HR 권한을 가진 기술 사용자(Technical User) 계정을 사용하지 마십시오. 조직도는 직원의 이름과 직책을 노출하므로 보안이 중요합니다.

## 2. 데이터가 저장되는 위치 (후보군)

| 앱 개념 | EC 내 후보 엔티티 | 비고 |
|---|---|---|
| 조직 단위 | Foundation Objects `FODepartment`, `FODivision`, `FOBusinessUnit` (or `Position`-based structure) | Foundation Object는 유효 시작/종료일(Effective-dated)이 관리되는 데이터입니다. 상위(Parent) 참조 관계를 통해 계층 구조를 형성합니다. 어떤 FO 유형으로 조직 트리를 구성할지는 고객사별로 다릅니다. |
| 부서장 | FO 엔티티 상의 부서장 정보 필드, 또는 부서원들의 `EmpJob` 상의 매니저(Manager) 필드 | 고객사의 데이터 모델링 방식에 따라 다릅니다. |
| 직원 및 부서 할당 | `EmpJob` (사용자 ID, 부서, 직책, 시작/종료일, 관리자 등) | 유효 기준일 데이터입니다. 입력받은 기준일(Key date)에 유효한 레코드를 사용합니다. |
| 직원 이름 | `PerPersonal` / `User` | 현재 유효한 레코드의 이름 정보입니다. |
| 포지션 기반 조직도 | 상위 포지션과 관계있는 `Position` | 포지션 관리만 사용될 때 |

SuccessFactors는 자체적인 *인사 조직도(Org Chart)* UI를 기본으로 제공합니다. 이 앱은 완전히 커스텀된 화면이 필요하거나,
동일한 UI 내에 다른 데이터 소스를 결합해야 하거나, 표준 기능과 다른 상호작용(Interaction) 방식이 필요할 때만 빌드하십시오.

## 3. 앱 내에서 교체해야 할 항목

1. `getTree(keyDate, query)`: 지정된 기준일에 유효한 부서 데이터를 읽어옵니다. (EC가 유효 기준일 엔티티에 대해 지원하는 `asOfDate` 파라미터 등을 활용한 읽기 방식 사용 - API 문서 확인 필요).
   클라이언트 측 또는 BTP CAP/ABAP 레이어와 같은 서버 측에서 계층 구조를 빌드하고, 부서장 이름과 인원 통계를 추가한 뒤 검색 필터를 적용합니다.
3. `getUnit(id, keyDate)`: 특정 부서 1개와 해당 부서의 상위 부서 체인 및 인원 통계를 가져옵니다.
4. `getMembers(id, keyDate, includeSub)`: 해당 부서(및 하위 부서 ID들)에 대해 지정된 기준일에 유효한 `EmpJob` 데이터를 읽어옵니다.
5. 이 함수들을 비동기(Promise) 방식으로 전환하고, `controller/OrgChart.controller.js` 내의 4개 호출부(`_loadTree`, `onSelect`, `_loadMembers`, 초기 로드 로직)를 이에 맞게 수정합니다.
6. 조직의 규모가 큰 경우(수천 개의 부서), 브라우저에 전체 트리를 한 번에 빌드하지 마십시오. 노드를 펼칠 때 하위 노드를 지연 로딩(Lazy loading) 하고(sap.m.Tree는 `toggleOpenState` 이벤트를 통해 이를 지원함),
   직원 목록은 페이징 처리(`$top` / `$skip` 을 활용한 서버 기반 페이징)를 구현하십시오.

## 4. 보안 및 개인정보 체크리스트

* 사용자 신원 전파(Propagated User) 방식을 사용하여 SF의 권한 체계를 엄격히 준수하십시오. 직원 데이터를 공유 스토리지에 캐싱하지 마십시오.
* 연락처, 생년월일, 급여 등의 민감한 데이터가 클라이언트단까지 도달해도 되는지 판단하고 통제하십시오. (본 프로토타입은 이러한 데이터를 일절 보여주지 않습니다.)
* 운영용(Production) 빌드 파일에 샘플 데이터가 포함되지 않도록 관리하십시오.

## 5. 프로토타입에 적용된 기지(Known)의 단순화 사항

* 단 하나의 고정된 부서 계층 구조 유형만 지원하며, 매트릭스(Matrix) 조직이나 점선 보고(Dotted-line) 관계는 지원하지 않습니다. 부서당 부서장은 1명으로 제한됩니다.
* 직원은 정확히 하나의 부서에만 소속됩니다. 겸직(Concurrent Employment)이나 글로벌 파견(Global Assignments)은 고려되지 않았습니다.
* 직원의 사진, 프로필 카드, 엑셀 내보내기 기능은 제공되지 않으며, 오직 조회(Read-only)만 가능합니다.

