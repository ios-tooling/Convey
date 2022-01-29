//
//  ServerTask+Cancellable.swift
//  ConveyTest
//
//  Created by Ben Gottlieb on 1/29/22.
//

import Foundation

public class ServerTaskWrapper<TargetTask: ServerTask> {
	let target: TargetTask
	init(task: TargetTask) {
		target = task
	}

	
}
