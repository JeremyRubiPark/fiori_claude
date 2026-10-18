# 조직도 - Employee Central 스타일 Fiori 프로토타입

조직 구조를 보여주는 프리스타일 SAPUI5 앱(sap.m.Tree 및 sap.ui.layout.Splitter 사용):

* 왼쪽 영역: 부서장(Manager) 및 인원수(하위 부서 포함) 정보가 표시되는 부서 트리 구조입니다. 부서명이나 ID로 검색할 수 있으며,
  검색 결과에 매칭된 부서와 상위 부서들은 하이라이트된 상태로 유지됩니다. 전체 확장 및 축소 기능이 제공됩니다.
* 오른쪽 영역: 선택한 부서의 상세 정보(조직 경로, 부서장, 유효 기간, 인원 통계)와 소속 직원 목록이 표시됩니다.
  옵션을 통해 하위 부서의 직원까지 모두 포함하여 볼 수 있습니다.
* 기준일(Key date): 부서와 직원은 지정한 기준일의 유효 기간에 따라 필터링되므로, 조직의 과거 및 미래 구조를 유연하게 조회할 수 있습니다.

모든 데이터는 인메모리(In-memory) 샘플 데이터이며 SuccessFactors 실제 연결은 없습니다. 자세한 연동 방법은 `docs/ec-integration.md` 를 참조하세요.

## 실행

SAP Business Application Studio (또는 로컬 Node 18+ 환경):

```bash
npm install
npm start          # http://localhost:8080/index.html  (BAS 환경에서는 PORTS 탭을 통해 포트를 오픈하세요)
npm test           # 로직 테스트 (Node) + 정적 검사
```

## 시나리오 테스트

| 시나리오 | 확인사항 |
|---|---|
| 오늘 |	1개의 최상위(Root) 부서와 4개의 부서가 표시됩니다. 이미 폐쇄된 "Legacy Sales Team"과 미래에 신설될 "Overseas Sales Team"은 숨겨집니다. |
| 기준일 2025-06-01 | "Legacy Sales Team"이 다시 나타나며, 2026년에 퇴사한 팀장도 함께 표시됩니다. |
| 기준일 2027-03-01 | 미래 신설 부서인 "Overseas Sales Team"이 화면에 나타납니다. |
| `recruit` 검색 | Recruiting Team과 그 상위 부서들만 화면에 남게 되며, 매칭된 팀은 하이라이트 처리됩니다. |
| 부서 선택 + "하위부서 포함" | IT Department 선택 시 직속 직원은 2명으로 표시되지만, 하위 부서를 포함하면 총 7명으로 늘어납니다. |

## 구조

```
webapp/model/OrgData.js    샘플 부서 및 직원 데이터
webapp/model/OrgLogic.js   서비스 계층 (SuccessFactors OData 호출 구조로 대체 가능)
webapp/view, controller    단일 페이지 구성: 트리 구조 + 상세 정보 영역
webapp/i18n                영어 (기본값) 및 한국어
test/                      OrgLogic에 대한 Node 테스트 및 정적 검사
```

## 배포

다른 앱들과 동일합니다: `ui5-deploy.yaml` 파일을 채우거나(또는 BAS에서 **Fiori: Add Deployment Configuration** 실행) `npm run deploy` 를 실행합니다.
BTP ABAP Trial 환경인 경우 아래 URL을 통해 앱을 열 수 있습니다:
`https://<abap-web-host>/sap/bc/ui5_ui5/sap/zec_orgchart/index.html`.

## 상태

* `OrgLogic.js`: 16개의 자동화 테스트를 통과했습니다. XML/JSON/JS 구문 및 i18n 키 반영 여부는 `test/static-check.js` 를 통해 검사됩니다.
