//
//  PhotoScoreViewController.swift
//  UIQACoreMLDemo
//
//  Created by Gavin Xiang on 10/16/26.
//  Copyright © 2026 PlanetArt. All rights reserved.
//

import CoreTransferable
import OSLog
import PhotosUI
import UIKit

private let log = Logger(subsystem: "com.planetart.UIQACoreMLDemo", category: "PhotoScoreUI")

final class PhotoScoreViewController: UIViewController {
    private let service: PhotoScoring
    private var scoreTask: Task<Void, Never>?

    private let contentStack = UIStackView()
    private let controlsStack = UIStackView()
    private let photoView = UIImageView()
    private let scoreLabel = UILabel()
    private let loadLabel = UILabel()
    private let statusLabel = UILabel()
    private let chooseButton = UIButton(configuration: .filled())
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(service: PhotoScoring) {
        self.service = service
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PhotoScoreViewController is created in code")
    }

    deinit {
        scoreTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.title = String(localized: "Core ML Score")
        configureViews()
        configureLayout()
        registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) { (self: Self, _) in
            self.updateArrangement()
        }
        updateArrangement()
        loadModel()
    }

    private func configureViews() {
        photoView.contentMode = .scaleAspectFit
        photoView.backgroundColor = .secondarySystemBackground
        photoView.layer.cornerRadius = 12
        photoView.clipsToBounds = true
        photoView.accessibilityLabel = String(localized: "Selected photo")
        photoView.isAccessibilityElement = true

        scoreLabel.font = .preferredFont(forTextStyle: .largeTitle)
        scoreLabel.adjustsFontForContentSizeCategory = true
        scoreLabel.textAlignment = .center
        scoreLabel.numberOfLines = 0
        scoreLabel.text = String(localized: "—")

        loadLabel.font = .preferredFont(forTextStyle: .headline)
        loadLabel.adjustsFontForContentSizeCategory = true
        loadLabel.textAlignment = .center
        loadLabel.numberOfLines = 0
        loadLabel.textColor = .label

        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.text = String(localized: "Loading Core ML model…")

        var configuration = UIButton.Configuration.filled()
        configuration.title = String(localized: "Choose Photo")
        configuration.cornerStyle = .medium
        chooseButton.configuration = configuration
        chooseButton.isEnabled = false
        chooseButton.addAction(UIAction { [weak self] _ in
            self?.choosePhoto()
        }, for: .touchUpInside)
        chooseButton.accessibilityLabel = String(localized: "Choose Photo")

        spinner.hidesWhenStopped = true
        spinner.startAnimating()

        contentStack.spacing = 20
        contentStack.alignment = .fill
        controlsStack.axis = .vertical
        controlsStack.spacing = 12
        controlsStack.alignment = .fill
    }

    private func configureLayout() {
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        controlsStack.addArrangedSubview(scoreLabel)
        controlsStack.addArrangedSubview(loadLabel)
        controlsStack.addArrangedSubview(statusLabel)
        controlsStack.addArrangedSubview(spinner)
        controlsStack.addArrangedSubview(chooseButton)
        contentStack.addArrangedSubview(photoView)
        contentStack.addArrangedSubview(controlsStack)
        view.addSubview(contentStack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: guide.bottomAnchor, constant: -20),
            photoView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),
            chooseButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
    }

    private func updateArrangement() {
        let isWide = traitCollection.horizontalSizeClass == .regular
            && traitCollection.verticalSizeClass == .regular
        contentStack.axis = isWide ? .horizontal : .vertical
        contentStack.distribution = isWide ? .fillEqually : .fill
    }

    private func loadModel() {
        scoreTask = Task { [weak self] in
            guard let self else { return }
            do {
                let elapsed = try await service.loadModel()
                guard !Task.isCancelled else { return }
                loadLabel.text = String(
                    format: String(localized: "Model loaded in %.2f seconds."),
                    Self.seconds(elapsed)
                )
                statusLabel.text = String(localized: "Choose a photo to score its quality.")
                chooseButton.isEnabled = true
            } catch {
                guard !Task.isCancelled else { return }
                log.error("Core ML load failed: \(error.localizedDescription, privacy: .public)")
                statusLabel.text = error.localizedDescription
            }
            spinner.stopAnimating()
        }
    }

    private func choosePhoto() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func score(_ image: UIImage) {
        scoreTask?.cancel()
        photoView.image = image
        scoreLabel.text = String(localized: "—")
        statusLabel.text = String(localized: "Scoring photo…")
        spinner.startAnimating()
        chooseButton.isEnabled = false
        scoreTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await service.score(image)
                guard !Task.isCancelled else { return }
                scoreLabel.text = String(format: "%.3f", result.value)
                statusLabel.text = String(
                    format: String(localized: "Quality score in %.2f seconds."),
                    Self.seconds(result.elapsed)
                )
            } catch {
                guard !Task.isCancelled else { return }
                log.error("Scoring failed: \(error.localizedDescription, privacy: .public)")
                scoreLabel.text = String(localized: "—")
                statusLabel.text = error.localizedDescription
            }
            spinner.stopAnimating()
            chooseButton.isEnabled = true
        }
    }

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}

extension PhotoScoreViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else { return }
        scoreTask?.cancel()
        statusLabel.text = String(localized: "Loading photo…")
        spinner.startAnimating()
        scoreTask = Task { [weak self] in
            do {
                let data = try await Self.loadPhotoData(from: provider)
                guard let image = UIImage(data: data) else {
                    throw PhotoScoreError.imageUnreadable
                }
                guard !Task.isCancelled else { return }
                self?.score(image)
            } catch {
                guard !Task.isCancelled else { return }
                self?.spinner.stopAnimating()
                self?.statusLabel.text = error.localizedDescription
            }
        }
    }

    private static func loadPhotoData(from provider: NSItemProvider) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadTransferable(type: Data.self) { result in
                continuation.resume(with: result)
            }
        }
    }
}
