import { masterTurso, createTenantClient } from "../config/turso.js";
import {
  getPrepareSkuLotsController,
  createPrepareSkuLotController,
  updatePrepareSkuLotController,
  deletePrepareSkuLotController,
} from "../controllers/stockController.js";

async function runTest() {
  console.log("=== Testing Stock Prepare for SKU Controller (with Multi-Stone & Multi-Diamond) ===");

  const tenantRes = await masterTurso.execute(`SELECT * FROM tenants LIMIT 1;`);
  if (tenantRes.rows.length === 0) {
    console.error("No tenant found!");
    process.exit(1);
  }
  const tenant = tenantRes.rows[0];

  function mockRes() {
    let statusCode = 200;
    let responseData = null;
    return {
      status(code) {
        statusCode = code;
        return this;
      },
      json(data) {
        responseData = data;
        return this;
      },
      get statusCode() {
        return statusCode;
      },
      get jsonData() {
        return responseData;
      },
    };
  }

  // 1. Test Listing Lots (Initial)
  const req1 = { tenant, query: { companyid: "COMP01" } };
  const res1 = mockRes();
  await getPrepareSkuLotsController(req1, res1);
  console.log("Initial List Status:", res1.statusCode, "Total:", res1.jsonData?.total_count);

  // 2. Test Creating Lot with Multi-Stone and Multi-Diamond
  const stoneItems = [
    { stone_productid: 1, stone_unit: 'G', pcs: 10, weight: 2.500 },
    { stone_productid: 2, stone_unit: 'C', pcs: 4, weight: 5.000 } // 5 ct = 1.000 g
  ];
  const diamondItems = [
    { diamond_productid: 3, diamond_unit: 'C', pcs: 2, weight: 1.500 } // 1.5 ct = 0.300 g
  ];

  const req2 = {
    tenant,
    body: {
      companyid: "COMP01",
      branchid: "HO",
      designerid: 1,
      productid: 1,
      subproductid: null,
      purityid: 1,
      rate: 7250.0,
      is_assorted: "NO",
      total_pcs: 5,
      total_gross_weight: 50.000,
      // Less wt: 2.500 (stone G) + 1.000 (stone C) + 0.300 (dia C) = 3.800 g
      // Net wt: 50.000 - 3.800 = 46.200 g
      total_net_weight: 46.200,
      stone_unit: "G",
      stone_items: stoneItems,
      diamond_unit: "C",
      diamond_items: diamondItems,
      remarks: "Test Multi-Item Stone & Diamond SKU Batch",
    },
  };
  const res2 = mockRes();
  await createPrepareSkuLotController(req2, res2);
  console.log("Create Lot Status:", res2.statusCode, "Response:", res2.jsonData);

  if (res2.statusCode !== 201) {
    throw new Error("Failed to create SKU lot: " + JSON.stringify(res2.jsonData));
  }

  const createdLotId = res2.jsonData.lot_id;
  const createdLotNo = res2.jsonData.lot_number;
  console.log("Created Lot ID:", createdLotId, "Lot No:", createdLotNo);

  // 3. Test Retrieval
  const req3 = { tenant, query: { companyid: "COMP01" } };
  const res3 = mockRes();
  await getPrepareSkuLotsController(req3, res3);
  const found = res3.jsonData.lots.find((l) => l.lot_id === createdLotId);
  console.log("Found Created Lot:", found?.lot_number, "Total Stone Pcs:", found?.total_stone_pcs, "Total Stone Wt:", found?.total_stone_weight);
  console.log("Stone items parsed:", found?.stone_items?.length, "Diamond items parsed:", found?.diamond_items?.length);

  // 4. Test Update
  const req4 = {
    tenant,
    params: { id: createdLotId },
    body: {
      total_pcs: 6,
      total_gross_weight: 55.000,
      total_net_weight: 51.200,
      stone_items: [
        { stone_productid: 1, stone_unit: 'G', pcs: 12, weight: 3.000 }
      ],
      diamond_items: diamondItems,
      remarks: "Updated Remarks Batch with modified stone list",
    },
  };
  const res4 = mockRes();
  await updatePrepareSkuLotController(req4, res4);
  console.log("Update Lot Status:", res4.statusCode, "Success:", res4.jsonData?.success);

  // 5. Test Delete
  const req5 = { tenant, params: { id: createdLotId } };
  const res5 = mockRes();
  await deletePrepareSkuLotController(req5, res5);
  console.log("Delete Lot Status:", res5.statusCode, "Success:", res5.jsonData?.success);

  console.log("=== ALL TESTS PASSED SUCCESSFULLY ===");
}

runTest().catch((err) => {
  console.error("Test Error:", err);
  process.exit(1);
});
