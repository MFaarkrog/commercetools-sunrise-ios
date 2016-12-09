//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import Quick
import Nimble
import ObjectMapper
import ReactiveSwift
import Result
@testable import Sunrise

class ProductViewModelSpec: QuickSpec {

    override func spec() {
        describe("ProductViewModel") {
            var productViewModel: ProductViewModel!

            beforeEach {
                let path = Bundle.currentTestBundle!.path(forResource: "product-projection", ofType: "json")!
                let productProjectionJSON = try! NSString(contentsOfFile: path, encoding: String.Encoding.utf8.rawValue)
                let product = Mapper<ProductProjection>().map(JSONString: productProjectionJSON as String)!

                productViewModel = ProductViewModel(product: product)
            }

            it("has the correct upper case name") {
                expect(productViewModel.name.value).toEventually(equal("SNEAKERS ”TOKYO” LOTTO GREY"))
            }

            it("has proper sizes extracted") {
                expect(productViewModel.attributes.value["size"]).toEventually(equal(["34", "34.5", "35", "35.5", "36", "36.5", "37", "37.5", "38", "38.5", "39", "39.5", "40", "40.5", "41", "41.5", "42", "42.5", "43", "43.5", "44", "44.5", "45", "45.5", "46"]))
            }

            it("initially has size selected from master variant") {
                expect(productViewModel.activeAttributes.value["size"]).toEventually(equal("34"))
            }

            it("initially has sku selected from master variant") {
                expect(productViewModel.sku.value).toEventually(equal("M0E20000000E7W1"))
            }

            it("initially has imageCount selected from master variant") {
                expect(productViewModel.imageCount.value).toEventually(equal(1))
            }

            it("initially has properly formatted price from master variant") {
                expect(productViewModel.price.value).toEventually(equal("€96.25"))
            }

            it("initially has properly formatted price before discount from master variant") {
                expect(productViewModel.oldPrice.value).toEventually(equal("€137.50"))
            }

            context("after changing selected size") {

                it("sku is updated") {
                    waitUntil { done in
                        productViewModel.isLoading.producer
                        .startWithValues({ isLoading in
                            if !isLoading {
                                productViewModel.activeAttributes.value["size"] = "38"
                                done()
                            }
                        })
                    }
                    waitUntil { done in
                        productViewModel.activeAttributes.producer
                        .startWithValues({ activeAttributes in
                            if activeAttributes["size"] == "38" {
                                expect(productViewModel.sku.value).to(equal("M0E20000000E7W9"))
                                done()
                            }
                        })
                    }
                }
            }
        }
    }
}
