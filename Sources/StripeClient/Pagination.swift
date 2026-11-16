import Foundation
import StripeModels

// Pagination helpers over the generated list types.

extension StripeClient {

  /// Walks a `/v1` list endpoint to the end (or `maxPages`), following
  /// `starting_after` cursors. Stripe's lists are reverse-chronological,
  /// so pages walk from newest to oldest.
  public static func collectAll<ListType: StripeList, Params: V1ListParams>(
    _ initialPage: ListType,
    params: Params,
    maxPages: Int = 100,
    fetch: @Sendable (Params) async throws -> ListType
  ) async throws -> [ListType.Item] where ListType.Item: StripeIdentified {
    var items: [ListType.Item] = initialPage.data
    var page = initialPage
    var currentParams = params
    var pagesFetched = 1
    while page.hasMore, pagesFetched < maxPages, let cursor = page.data.last?.id {
      currentParams.startingAfter = cursor
      page = try await fetch(currentParams)
      items.append(contentsOf: page.data)
      pagesFetched += 1
    }
    return items
  }

  /// Walks a `/v2` page chain to the end (or `maxPages`), following
  /// `next_page_url` tokens.
  public static func collectAllV2<PageType: V2Page>(
    _ initialPage: PageType,
    maxPages: Int = 100,
    fetch: @Sendable (String?) async throws -> PageType
  ) async throws -> [PageType.Item] {
    var items: [PageType.Item] = initialPage.data
    var page = initialPage
    var pagesFetched = 1
    var nextToken: String? = page.nextPageUrlToken.flatMap(Self.pageToken(fromUrl:))
    while nextToken != nil, pagesFetched < maxPages {
      page = try await fetch(nextToken)
      items.append(contentsOf: page.data)
      pagesFetched += 1
      nextToken = page.nextPageUrlToken.flatMap(Self.pageToken(fromUrl:))
    }
    return items
  }

  /// Extracts the `page` token from a `/v2` next-page URL.
  static func pageToken(fromUrl urlString: String) -> String? {
    guard let url = URL(string: urlString),
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let items = components.queryItems
    else { return nil }
    for item in items {
      if item.name == "page" {
        return item.value
      }
    }
    return nil
  }
}
