import UIKit

extension ScannerViewController {
    func makeTargetBraceButton() -> UIView {
        let view = blurView()

        let image = UIImageView(image: .targetBracesToggleImage)
        image.translatesAutoresizingMaskIntoConstraints = false
        view.contentView.addSubview(image)
        view.centerXAnchor.constraint(equalTo: image.centerXAnchor).isActive = true
        view.centerYAnchor.constraint(equalTo: image.centerYAnchor).isActive = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleTargetBraces))
        view.addGestureRecognizer(tap)

        return view
    }

    func makeTorchButton() -> UIView {
        let view = blurView()

        let image = UIImageView(image: .torchImage)
        image.translatesAutoresizingMaskIntoConstraints = false
        view.contentView.addSubview(image)
        view.centerXAnchor.constraint(equalTo: image.centerXAnchor).isActive = true
        view.centerYAnchor.constraint(equalTo: image.centerYAnchor).isActive = true

        let action = #selector(showTorchUI)
        if UIScreen.main.traitCollection.forceTouchCapability == .available {
            let forceTap = ForceTouchGestureRecognizer(target: self, action: action)
            view.addGestureRecognizer(forceTap)
        } else {
            let tap = UITapGestureRecognizer(target: self, action: #selector(toggleTorch))
            view.addGestureRecognizer(tap)

            let longPress = UILongPressGestureRecognizer(target: self, action: action)
            view.addGestureRecognizer(longPress)
        }

        return view
    }

    func takePhotoButton() -> UIButton {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(.buttonImage, for: .normal)
        button.addTarget(self,
                         action: #selector(captureScreen),
                         for: .touchUpInside)
        return button
    }

    func makeProgressBar() -> UIProgressView {
        let progressBar = UIProgressView()
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        return progressBar
    }
    
    func makeAccuracyView() -> (UIView, UILabel) {
        let accuracyView = UIView()
        accuracyView.translatesAutoresizingMaskIntoConstraints = false
        accuracyView.backgroundColor = UIColor.black
        let accuracyLabel = UILabel()
        accuracyLabel.translatesAutoresizingMaskIntoConstraints = false
        accuracyLabel.font = UIFont.systemFont(ofSize: 12)
        accuracyLabel.textColor = UIColor.white
        accuracyView.addSubview(accuracyLabel)
        NSLayoutConstraint.activate([
            accuracyLabel.leadingAnchor.constraint(equalTo: accuracyView.leadingAnchor, constant: 12.0),
            accuracyLabel.trailingAnchor.constraint(equalTo: accuracyView.trailingAnchor, constant: -12.0),
            accuracyLabel.topAnchor.constraint(equalTo: accuracyView.topAnchor, constant: 8.0),
            accuracyLabel.bottomAnchor.constraint(equalTo: accuracyView.bottomAnchor, constant: -8.0)
        ])
        return (accuracyView, accuracyLabel)
    }
}

private func blurView() -> UIVisualEffectView {
    let blurEffect = UIBlurEffect(style: .light)
    let view = UIVisualEffectView(effect: blurEffect)
    view.translatesAutoresizingMaskIntoConstraints = false
    view.widthAnchor.constraint(equalToConstant: 64).isActive = true
    view.heightAnchor.constraint(equalTo: view.widthAnchor).isActive = true
    view.layer.cornerRadius = 12
    view.clipsToBounds = true

    return view
}
