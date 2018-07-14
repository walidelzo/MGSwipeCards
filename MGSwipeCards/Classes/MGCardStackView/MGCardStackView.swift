//
//  MGCardStackView.swift
//  MGSwipeCards
//
//  Created by Mac Gallagher on 5/4/18.
//  Copyright © 2018 Mac Gallagher. All rights reserved.
//

import UIKit

open class MGCardStackView: UIView {
    
    open var delegate: MGCardStackViewDelegate?
    
    public var dataSource: MGCardStackViewDataSource? {
        didSet { reloadData() }
    }
    
    open var horizontalInset: CGFloat = 10.0 {
        didSet { setNeedsLayout() }
    }
    
    open var verticalInset: CGFloat = 10.0 {
        didSet { setNeedsLayout() }
    }
    
    private var lastSwipedCard: MGSwipeCard?
    private var lastSwipedCardIsVisible: Bool {
        return lastSwipedCard?.frame.intersects(UIScreen.main.bounds) ?? false
    }
    
    private var visibleCards: [MGSwipeCard] = []
    
    private var states: [[Int]] = []
    private var currentState: [Int] {
        return states.last ?? []
    }
    public var currentCardIndex: Int {
        return currentState.first ?? 0
    }
    
    private var cardStack = UIView()
    
    private static var numberOfVisibleCards: Int = 2
    private static var backgroundCardScaleFactor: CGFloat = 0.95
    
    //MARK: - Initialization
    
    public init() {
        super.init(frame: .zero)
        sharedInit()
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        sharedInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        sharedInit()
    }
    
    private func sharedInit() {
        addSubview(cardStack)
    }
    
    //MARK: - Layout

    open override func layoutSubviews() {
        super.layoutSubviews()
        cardStack.frame = CGRect(x: horizontalInset, y: verticalInset, width: bounds.width - 2 * horizontalInset, height: bounds.height - 2 * verticalInset)
        for (index, card) in visibleCards.enumerated() {
            layoutCard(card, at: index)
        }
    }
    
    private func layoutCardStack() {
        for (index, card) in visibleCards.enumerated() {
            layoutCard(card, at: index)
        }
    }
    
    //translate center instead of origin for offset
    private func layoutCard(_ card: MGSwipeCard, at index: Int) {
        card.transform = CGAffineTransform.identity
        card.frame = cardStack.bounds
        if index == 0 {
            card.isUserInteractionEnabled = true
        } else {
            card.transform = CGAffineTransform(scaleX: MGCardStackView.backgroundCardScaleFactor, y: MGCardStackView.backgroundCardScaleFactor)
            card.isUserInteractionEnabled = false
        }
    }
    
    //MARK: - Data Source
    
    public func reloadData() {
        guard let dataSource = dataSource else { return }
        let numberOfCards = dataSource.numberOfCards(in: self)
        states = []
        lastSwipedCard = nil
        let freshState = Array(0..<numberOfCards)
        states.append(freshState)
        loadState(at: 0)
    }
    
    private func loadState(at index: Int) {
        visibleCards.forEach { card in
            card.removeFromSuperview()
        }
        visibleCards = []
        states.removeLast(states.count - (index + 1))
        for index in 0..<min(currentState.count, MGCardStackView.numberOfVisibleCards) {
            if let card = reloadCard(at: currentState[index]) {
                insertCard(card, at: index)
            }
        }
        if states.count <= 1 {
            lastSwipedCard = nil
        } else {
            let stateDifference = states[states.count - 2].difference(from: states[states.count - 1])
            lastSwipedCard = dataSource?.cardStack(self, cardForIndexAt: stateDifference[0])
        }
    }
    
    private func insertCard(_ card: MGSwipeCard, at index: Int) {
        cardStack.insertSubview(card, at: visibleCards.count - index)
        visibleCards.insert(card, at: index)
    }
    
    private func reloadCard(at index: Int) -> MGSwipeCard? {
        guard let dataSource = dataSource else { return nil }
        let card = dataSource.cardStack(self, cardForIndexAt: index)
        if let options = delegate?.cardStack(self, additionalOptionsForCardAt: index) {
            card.options = options
        }
        card.delegate = self
        return card
    }
    
    //MARK: - Main Methods
    
    public func swipe(_ direction: SwipeDirection) {
        if visibleCards.count <= 0 { return }
        if lastSwipedCardIsVisible { return }
        let topCard = visibleCards[0]
        if topCard.isSwipeAnimating { return }
        topCard.swipe(withDirection: direction)
    }
    
    public func undoLastSwipe() -> MGSwipeCard? {
        if states.count <= 1 { return nil }
        if lastSwipedCardIsVisible { return nil }
        if visibleCards.count > 0, visibleCards[0].isSwipeAnimating { return nil }
        let removedCard = lastSwipedCard
        removedCard?.undoSwipe()
        return removedCard
    }

    public func shift(withDistance distance: Int = 1) {
        if distance == 0 || visibleCards.count <= 1 { return }
        if lastSwipedCardIsVisible || visibleCards[0].isSwipeAnimating { return }
        let newState = currentState.shift(withDistance: distance)
        states.removeLast()
        states.append(newState)
        loadState(at: self.states.count - 1)
        layoutCardStack()
    }
    
}

//MARK: - MGSwipeCardDelegate

extension MGCardStackView: MGSwipeCardDelegate {
    
    public func card(didTap card: MGSwipeCard, location: CGPoint) {
        delegate?.cardStack(self, didSelectCardAt: currentCardIndex, touchPoint: location)
    }
    
    public func card(didBeginSwipe card: MGSwipeCard) {
        //stop next card from animating
    }
    
    public func card(didContinueSwipe card: MGSwipeCard) {
        if visibleCards.count <= 1 { return }
        let topCard = visibleCards[0]
        let translation = topCard.panGestureRecognizer.translation(in: cardStack)
        let minimumSideLength = min(cardStack.bounds.width, cardStack.bounds.height)
        let percentTranslation = max(min(1, 2 * abs(translation.x)/minimumSideLength), min(1, 2 * abs(translation.y)/minimumSideLength))
        let scaleFactor = MGCardStackView.backgroundCardScaleFactor + (1 - MGCardStackView.backgroundCardScaleFactor) * percentTranslation
        let nextCard = visibleCards[1]
        nextCard.layer.setAffineTransform(CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
    }
    
    public func card(didSwipe card: MGSwipeCard, with direction: SwipeDirection) {
        delegate?.cardStack(self, didSwipeCardAt: currentCardIndex, with: direction)
        visibleCards.remove(at: 0)
        lastSwipedCard = card
        states.append(Array(currentState.dropFirst()))
        
        //no cards left
        if currentState.count == 0 {
            delegate?.didSwipeAllCards(self)
            return
        }

        //at least one more card to load
        if currentState.count - visibleCards.count > 0 {
            let bottomCardIndex = currentState[visibleCards.count]
            if let card = reloadCard(at: bottomCardIndex) {
                insertCard(card, at: visibleCards.count)
                layoutCard(card, at: visibleCards.count)
            }
        }
        
        //stop this from animating if needed
        let delay = visibleCards[0].options.overlayFadeInOutDuration
        UIView.animate(withDuration: 0.2, delay: delay, options: .curveLinear, animations: {
            self.layoutCardStack()
        }, completion: nil)
        
        Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(handleInteractionTimer), userInfo: nil, repeats: true)
    }
    
    @objc private func handleInteractionTimer(_ timer: Timer) {
        if !lastSwipedCardIsVisible {
            if visibleCards.count > 0 {
                visibleCards[0].isUserInteractionEnabled = true
            }
            timer.invalidate()
        }
    }
    
    public func card(didCancelSwipe card: MGSwipeCard) {
        if visibleCards.count <= 1 { return }
        //stop this from animating if needed
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveLinear, animations: {
            for index in 1..<self.visibleCards.count {
                self.layoutCard(self.visibleCards[index], at: index)
            }
        }, completion: nil)
    }
    
    public func card(didUndoSwipe card: MGSwipeCard) {
        loadState(at: self.states.count - 2)
        for index in 1..<visibleCards.count {
            UIView.animate(withDuration: 0.2, animations: {
                self.layoutCard(self.visibleCards[index], at: index)
            })
        }
    }
    
}












