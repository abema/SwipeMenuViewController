import UIKit

public protocol ContentScrollViewDataSource {

    func numberOfPages(in contentScrollView: ContentScrollView) -> Int

    func contentScrollView(_ contentScrollView: ContentScrollView, viewForPageAt index: Int) -> UIView?
}

open class ContentScrollView: UIScrollView {

    open var dataSource: ContentScrollViewDataSource?

    fileprivate var pageViews: [UIView] = []

    fileprivate var currentIndex: Int = 0

    fileprivate var options: SwipeMenuViewOptions.ContentScrollView = SwipeMenuViewOptions.ContentScrollView()

    private var visiblePageViews: [Int: UIView] = [:]

    /// next page count to setup
    private let nextBufferPageCount: Int = 1

    private var visiblePageViewRange: CountableClosedRange<Int>? {
        let previousPageIndex: Int = {
            let i = currentIndex - options.preloadingPageCount
            return max(i, 0)
        }()
        let nextPageIndex: Int = {
            let i = currentIndex + options.preloadingPageCount
            let lastIndex = pageViews.count - 1
            return min(lastIndex, i)
        }()

        guard nextPageIndex > previousPageIndex else { return nil }
        return previousPageIndex...nextPageIndex
    }

    public init(frame: CGRect, default defaultIndex: Int, options: SwipeMenuViewOptions.ContentScrollView? = nil) {
        super.init(frame: frame)

        currentIndex = defaultIndex

        if #available(iOS 11.0, *) {
            self.contentInsetAdjustmentBehavior = .never
        }

        if let options = options {
            self.options = options
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func didMoveToSuperview() {
        setup()
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        self.contentSize = CGSize(width: frame.width * CGFloat(pageViews.count), height: frame.height)
    }

    public func reset() {
        pageViews = []
        currentIndex = 0
    }

    public func reload() {
        self.didMoveToSuperview()
    }

    public func update(_ newIndex: Int) {
        guard currentIndex != newIndex else { return }
        currentIndex = newIndex
        setVisiblePageViews()
    }

    // MARK: - Setup

    fileprivate func setup() {

        guard let dataSource = dataSource else { return }
        if dataSource.numberOfPages(in: self) <= 0 { return }

        setupScrollView()
        setupContainerPageViews()
        setVisiblePageViews()
    }

    fileprivate func setupScrollView() {
        backgroundColor = options.backgroundColor
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        isScrollEnabled = options.isScrollEnabled
        isPagingEnabled = true
        isDirectionalLockEnabled = false
        alwaysBounceHorizontal = false
        scrollsToTop = false
        bounces = false
        bouncesZoom = false
        setContentOffset(.zero, animated: false)
    }

    /// setup empty containerView for `dataSource.numberOfPages(in:)`,
    /// so that pageView is lazily added.
    private func setupContainerPageViews() {
        pageViews = []

        guard let dataSource = dataSource, dataSource.numberOfPages(in: self) > 0 else { return }

        self.contentSize = CGSize(width: frame.width * CGFloat(dataSource.numberOfPages(in: self)), height: frame.height)

        for i in 0...currentIndex {
            let containerView = UIView()
            pageViews.append(containerView)
            addSubview(containerView)

            let leadingAnchor = i > 0 ? pageViews[i - 1].trailingAnchor : self.leadingAnchor
            containerView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                containerView.topAnchor.constraint(equalTo: self.topAnchor),
                containerView.widthAnchor.constraint(equalTo: self.widthAnchor),
                containerView.heightAnchor.constraint(equalTo: self.heightAnchor),
                containerView.leadingAnchor.constraint(equalTo: leadingAnchor)
            ])
        }

        guard currentIndex < dataSource.numberOfPages(in: self) else { return }
        for i in (currentIndex + 1)..<dataSource.numberOfPages(in: self) {
            let containerView = UIView()
            pageViews.append(containerView)
            addSubview(containerView)

            containerView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                containerView.topAnchor.constraint(equalTo: self.topAnchor),
                containerView.widthAnchor.constraint(equalTo: self.widthAnchor),
                containerView.heightAnchor.constraint(equalTo: self.heightAnchor),
                containerView.leadingAnchor.constraint(equalTo: pageViews[i - 1].trailingAnchor)
            ])
        }
    }

    /// lazily setup
    /// - set current pageView and the buffered previous/next pageView
    /// - remove outside pageView
    private func setVisiblePageViews() {
        guard let dataSource = self.dataSource else { return }
        guard let visiblePageViewRange = visiblePageViewRange else { return }

        // remove pageView outside the range
        for (index, pageView) in visiblePageViews where !visiblePageViewRange.contains(index) {
            pageView.removeFromSuperview()
            visiblePageViews.removeValue(forKey: index)
        }

        // add newly included pageViews
        for index in visiblePageViewRange where visiblePageViews[index] == nil {
            guard let pageView = dataSource.contentScrollView(self, viewForPageAt: index) else { return }
            visiblePageViews[index] = pageView

            let containerView = pageViews[index]
            containerView.addSubview(pageView)
            pageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                pageView.topAnchor.constraint(equalTo: containerView.topAnchor),
                pageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                pageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                pageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
        }
    }
}

extension ContentScrollView {

    var currentPage: UIView? {

        if currentIndex < pageViews.count && currentIndex >= 0 {
            return pageViews[currentIndex]
        }

        return nil
    }

    var nextPage: UIView? {

        if currentIndex < pageViews.count - 1 {
            return pageViews[currentIndex + 1]
        }

        return nil
    }

    var previousPage: UIView? {

        if currentIndex > 0 {
            return pageViews[currentIndex - 1]
        }

        return nil
    }

    public func jump(to index: Int, animated: Bool) {
        update(index)
        self.setContentOffset(CGPoint(x: self.frame.width * CGFloat(currentIndex), y: 0), animated: animated)
    }
}
