// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import UIKit
import Shared

protocol FindInPageBarDelegate: AnyObject {
    func findInPage(_ findInPage: FindInPageBar, didTextChange text: String)
    func findInPage(_ findInPage: FindInPageBar, didFindPreviousWithText text: String)
    func findInPage(_ findInPage: FindInPageBar, didFindNextWithText text: String)
    func findInPageDidPressClose(_ findInPage: FindInPageBar)
}

class FindInPageBar: UIView, ThemeApplicable {
    private struct UX {
        static let fontSize: CGFloat = 16
    }

    private static let savedTextKey = "findInPageSavedTextKey"

    weak var delegate: FindInPageBarDelegate?

    private lazy var topBorder: UIView = .build()

    private lazy var searchText: UITextField = .build { textField in
        textField.addTarget(self, action: #selector(self.didTextChange), for: .editingChanged)
        textField.font = DefaultDynamicFontHelper.preferredFont(withTextStyle: .callout, size: UX.fontSize)
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []
        textField.enablesReturnKeyAutomatically = true
        textField.returnKeyType = .search
        textField.accessibilityIdentifier = "FindInPage.searchField"
        textField.delegate = self
    }

    private lazy var matchCountView: UILabel = .build { label in
        label.font = DefaultDynamicFontHelper.preferredFont(withTextStyle: .callout, size: UX.fontSize)
        label.isHidden = true
        label.accessibilityIdentifier = "FindInPage.matchCount"
    }

    private lazy var previousButton: UIButton = .build { button in
        button.setImage(UIImage(named: StandardImageIdentifiers.Large.chevronUp), for: .normal)
        button.accessibilityLabel = .FindInPagePreviousAccessibilityLabel
        button.addTarget(self, action: #selector(self.didFindPrevious), for: .touchUpInside)
        button.accessibilityIdentifier = AccessibilityIdentifiers.FindInPage.findPreviousButton
    }

    private lazy var nextButton: UIButton = .build { button in
        button.setImage(UIImage(named: StandardImageIdentifiers.Large.chevronDown), for: .normal)
        button.accessibilityLabel = .FindInPageNextAccessibilityLabel
        button.addTarget(self, action: #selector(self.didFindNext), for: .touchUpInside)
        button.accessibilityIdentifier = AccessibilityIdentifiers.FindInPage.findNextButton
    }

    private lazy var closeButton: UIButton = .build { button in
        button.setImage(UIImage(named: StandardImageIdentifiers.Medium.cross), for: .normal)
        button.accessibilityLabel = .FindInPageDoneAccessibilityLabel
        button.addTarget(self, action: #selector(self.didPressClose), for: .touchUpInside)
        button.accessibilityIdentifier = "FindInPage.close"
    }

    var currentResult = 0 {
        didSet {
            if totalResults > 500 {
                matchCountView.text = "\(currentResult)/500+"
            } else {
                matchCountView.text = "\(currentResult)/\(totalResults)"
            }
        }
    }

    var totalResults = 0 {
        didSet {
            if totalResults > 500 {
                matchCountView.text = "\(currentResult)/500+"
            } else {
                matchCountView.text = "\(currentResult)/\(totalResults)"
            }
            previousButton.isEnabled = totalResults > 1
            nextButton.isEnabled = previousButton.isEnabled
        }
    }

    var text: String? {
        get {
            return searchText.text
        }

        set {
            searchText.text = newValue
            didTextChange(searchText)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .white

        addSubviews(searchText, matchCountView, previousButton, nextButton, closeButton, topBorder)

        searchText.snp.makeConstraints { make in
            make.leading.top.bottom.equalTo(self).inset(UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0))
        }
        searchText.setContentHuggingPriority(.defaultLow, for: .horizontal)
        searchText.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        matchCountView.snp.makeConstraints { make in
            make.leading.equalTo(searchText.snp.trailing)
            make.centerY.equalTo(self)
        }
        matchCountView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        matchCountView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        previousButton.snp.makeConstraints { make in
            make.leading.equalTo(matchCountView.snp.trailing)
            make.size.equalTo(self.snp.height)
            make.centerY.equalTo(self)
        }

        nextButton.snp.makeConstraints { make in
            make.leading.equalTo(previousButton.snp.trailing)
            make.size.equalTo(self.snp.height)
            make.centerY.equalTo(self)
        }

        closeButton.snp.makeConstraints { make in
            make.leading.equalTo(nextButton.snp.trailing)
            make.size.equalTo(self.snp.height)
            make.trailing.centerY.equalTo(self)
        }

        topBorder.snp.makeConstraints { make in
            make.height.equalTo(1)
            make.left.right.top.equalTo(self)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        searchText.becomeFirstResponder()
        return super.becomeFirstResponder()
    }

    @objc
    private func didFindPrevious(_ sender: UIButton) {
        delegate?.findInPage(self, didFindPreviousWithText: searchText.text ?? "")
    }

    @objc
    private func didFindNext(_ sender: UIButton) {
        delegate?.findInPage(self, didFindNextWithText: searchText.text ?? "")
    }

    @objc
    private func didTextChange(_ sender: UITextField) {
        matchCountView.isHidden = searchText.text?.trimmingCharacters(in: .whitespaces).isEmpty ?? true
        saveSearchText(searchText.text)
        delegate?.findInPage(self, didTextChange: searchText.text ?? "")
    }

    @objc
    private func didPressClose(_ sender: UIButton) {
        delegate?.findInPageDidPressClose(self)
    }

    private func saveSearchText(_ searchText: String?) {
        guard let text = searchText, !text.isEmpty else { return }
        UserDefaults.standard.set(text, forKey: FindInPageBar.savedTextKey)
    }

    static var retrieveSavedText: String? {
        return UserDefaults.standard.object(forKey: FindInPageBar.savedTextKey) as? String
    }

    // MARK: - Theme Applicable
    func applyTheme(theme: Theme) {
        let colors = theme.colors
        topBorder.backgroundColor = colors.borderPrimary
        searchText.textColor = theme.type == .light ? colors.textPrimary : colors.textInverted
        matchCountView.textColor = colors.actionSecondary
        previousButton.setTitleColor(colors.iconPrimary, for: .normal)
        nextButton.setTitleColor(colors.iconPrimary, for: .normal)
        closeButton.setTitleColor(colors.iconPrimary, for: .normal)
    }
}

extension FindInPageBar: UITextFieldDelegate {
    // Keyboard with a .search returnKeyType doesn't dismiss when return pressed. Handle this manually.
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string == "\n" {
            textField.resignFirstResponder()
            return false
        }
        return true
    }
}
