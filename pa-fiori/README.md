# PA20 / PA30 스타일 인사 마스터 데이터 - Fiori 프로토타입

두 가지 HR 트랜잭션을 모방한 프리스타일 SAPUI5 앱(sap.m, sap.uxap.ObjectPageLayout 사용):

* **조회** (PA20): 직원을 검색하고, 특정 기준일(Key date) 또는 전체 기간에 유효한 인포타입 레코드를 표시합니다.
* **유지보수** (PA30): *수정(Edit)*을 선택하면(해당 직원 레코드 잠금), SAP HR과 동일한 시간 제약 규칙(Time-Constraint Rules)을 적용하여
                       레코드를 **생성 / 복사 / 변경 / 유효기간 한정(Delimit) / 삭제**합니다 (TC1: 공백/중복 불가, TC2: 서브타입별 적용).

* **인사발령** (PA40): 검색 페이지 또는 직원 페이지(조회 모드에서도 가능)에서 *인사발령* 을 선택합니다.
  채용(01), 조직 변경(02), 퇴사(10) 기능은 하나의 단계에서 0000(인사명령) 레코드와 해당 발령 정보 그룹(Info Group)의
  인포타입(채용: 0002, 0001, 0006 / 조직 변경: 0001)을 함께 작성합니다.
  어느 한 단계라도 실패하면 아무것도 저장되지 않습니다. 발령 코드 03(급여 변경)은 인포타입 0008이 필요하므로 제공되지 않습니다.

인포타입: 0000 인사명령(조회 전용), 0001 조직 할당, 0002 개인 데이터, 0006 주소.
모든 데이터는 인메모리(In-memory) 샘플 데이터이며 ECC 연결은 없습니다. ECC로 연결하는 경로는 `docs/ecc-integration.md` 를 참조하세요.

## 실행

SAP Business Application Studio (또는 local Node 18+ 환경):

```bash
npm install
npm start          # http://localhost:8080/index.html
npm test           # 로직 테스트 (Node) + 정적 검사
```

검색 페이지의 모드 버튼을 사용하여 조회 모드와 유지보수 모드 간을 전환하거나, `index.html?mode=maintain` 또는 Launchpad 타일 파라미터 `mode=maintain` 을 사용하여 시작할 수 있습니다.
샘플 데이터를 초기화하려면 페이지를 새로고침하세요.

## 시나리오 테스트

| 시나리오 | 사원번호 | 확인사 |
|---|---|---|
| 일반 이력 (Normal history) | 10000001 | 여러 기간에 걸친 레코드 확인; 기준일을 2021-03-01 로 설정 |
| 다른 사용자가 잠금 (Locked by other user) | 10000004 | 유지보수 모드 -> 수정(Edit) 클릭 시 "locked by HRADMIN2" 메시지 표시 |
| 퇴사자 (Leaver) | 10000005 | 상태가 퇴사(Withdrawn)로 표시됨; 마지막 0000 레코드 확인 |
| 미래 채용자 (Future hire) | 10000006 | 기준일을 오늘로 설정: 가장 가까운 날짜의 레코드가 표시됨 |
| TC1 삽입 (TC1 insert) | 임의 사원 | 기간 중간의 시작일(begda)로 0001 레코드를 생성; 이전 레코드의 유효기간이 한정(Delimit)됨 |
| TC2 주소 (TC2 addresses) | 10000001 | 유효기간 한정, 중복 오류, 서로 다른 서브타입이 나란히 존재하는지 확인 |
| 채용 (Hiring) | 신규 (new) | 인사발령 -> 채용 선택; 0002/0001/0006을 입력하면 새 사원 번호가 부여됨; 필수 필드를 비워두어 아무것도 저장되지 않는지 확인 |
| 조직 변경 / 퇴사 (Reassignment / Leaving) | 10000002	직원 페이지 -> 인사발령; 퇴사자(10000005)나 잠긴 직원(10000004)을 퇴사 처리하려고 하면 거부됨 |
| TC1 삭제 (Delete TC1) | 임의 사원 | 이전 레코드의 기간이 연장됨; 마지막 레코드는 삭제할 수 없음 |

## ABAP 환경에 배포 (BTP Trial)

SuccessFactors 앱과 동일합니다: BAS에서 **Fiori: Add Deployment Configuration** 을 실행하거나 `ui5-deploy.yaml` 파일을 채운 후 `npm run deploy` 를 실행합니다.
Trial 버전에는 Launchpad 롤(Role) 유지보수 기능이 없으므로 아래 URL을 통해 앱을 엽니다:
`https://<abap-web-host>/sap/bc/ui5_ui5/sap/zpa_hr/index.html.`

## 구조

```
webapp/model/infotypes.js   인포타입 메타데이터 + 샘플 코드 목록 (데이터 기반 UI)
webapp/model/PALogic.js     서비스 계층 (ECC 연결 시 OData V2로 대체 가능)
webapp/model/MockData.js    sample 직원 및 레코드
webapp/view, controller     검색 및 직원 페이지 (섹션/테이블은 infotypes.js를 기반으로 생성됨)
webapp/i18n                 영어 (기본값) 및 한국어
test/                       PALogic에 대한 Node 테스트 및 정적 검사
```

## 상태

* `PALogic.js`: 트랜잭션 단위의 인사발령을 포함하여 44개의 자동화 테스트를 통과했습니다.
* XML/JSON/JS 구문 및 i18n 키 반영 여부는 `test/static-check.js` 를 통해 검사됩니다.
